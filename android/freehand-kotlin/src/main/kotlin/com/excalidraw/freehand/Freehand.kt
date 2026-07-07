package com.excalidraw.freehand

import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/**
 * A pure-Kotlin (JVM) port of [perfect-freehand](https://github.com/steveruizok/perfect-freehand)'s
 * `getStroke`. Given a sequence of input points (with optional pressure), it produces the closed
 * outline polygon of a variable-width stroke, ready to be filled.
 */

/** A single input sample. [pressure] is in the 0..1 range. */
data class StrokePoint(val x: Double, val y: Double, val pressure: Double = 0.5)

/** Options controlling the shape of the generated stroke, matching perfect-freehand's defaults. */
data class StrokeOptions(
    val size: Double = 16.0,
    val thinning: Double = 0.5,
    val smoothing: Double = 0.5,
    val streamline: Double = 0.5,
    val simulatePressure: Boolean = true,
    val last: Boolean = true,
    val capStart: Boolean = true,
    val capEnd: Boolean = true,
)

/** How quickly simulated pressure responds to changes in speed. */
private const val RATE_OF_PRESSURE_CHANGE = 0.275

/** perfect-freehand uses a slightly-larger-than-PI value to avoid degenerate rotations. */
private const val FIXED_PI = PI + 0.0001

/**
 * Compute the outline polygon for [points] using [options]. Returns an empty list for empty input.
 */
fun getStroke(
    points: List<StrokePoint>,
    options: StrokeOptions = StrokeOptions(),
): List<Pair<Double, Double>> = getStrokeOutlinePoints(getStrokePoints(points, options), options)

/** Intermediate per-vertex data produced by [getStrokePoints]. */
internal data class PathPoint(
    var point: V,
    val pressure: Double,
    var vector: V,
    val distance: Double,
    val runningLength: Double,
)

/**
 * Stage 1: streamline and resample the raw input, computing a direction vector, segment distance
 * and running length for each retained point.
 */
internal fun getStrokePoints(rawPoints: List<StrokePoint>, options: StrokeOptions): List<PathPoint> {
    if (rawPoints.isEmpty()) return emptyList()

    val streamline = options.streamline
    val size = options.size
    val isComplete = options.last

    // Interpolation factor between successive points.
    val t = 0.15 + (1 - streamline) * 0.85

    // Convert to mutable (x, y, pressure) triples.
    var pts = rawPoints.map { Triple(it.x, it.y, it.pressure) }.toMutableList()

    // Add extra points between two, to avoid sharp lines.
    if (pts.size == 2) {
        val last = pts[1]
        val first = pts[0]
        pts = mutableListOf(first)
        for (i in 1..4) {
            val p = lrp(V(first.first, first.second), V(last.first, last.second), i / 4.0)
            pts.add(Triple(p.x, p.y, last.third))
        }
    }

    // If there's only one point, add another at a 1pt offset.
    if (pts.size == 1) {
        val only = pts[0]
        pts.add(Triple(only.first + 1.0, only.second + 1.0, only.third))
    }

    val strokePoints = mutableListOf(
        PathPoint(
            point = V(pts[0].first, pts[0].second),
            pressure = if (pts[0].third >= 0) pts[0].third else 0.25,
            vector = V(1.0, 1.0),
            distance = 0.0,
            runningLength = 0.0,
        ),
    )

    var hasReachedMinimumLength = false
    var runningLength = 0.0
    var prev = strokePoints[0]
    val maxIndex = pts.size - 1

    for (i in 1 until pts.size) {
        val raw = pts[i]
        val point = if (isComplete && i == maxIndex) {
            V(raw.first, raw.second)
        } else {
            lrp(prev.point, V(raw.first, raw.second), t)
        }

        if (isEqual(prev.point, point)) continue

        val distance = dist(point, prev.point)
        runningLength += distance

        // Skip early points until we've accumulated enough length (unless it's the last point).
        if (i < maxIndex && !hasReachedMinimumLength) {
            if (runningLength < size) continue
            hasReachedMinimumLength = true
        }

        prev = PathPoint(
            point = point,
            pressure = if (raw.third >= 0) raw.third else 0.5,
            vector = uni(sub(prev.point, point)),
            distance = distance,
            runningLength = runningLength,
        )
        strokePoints.add(prev)
    }

    // First point inherits the second point's direction.
    strokePoints[0].vector = strokePoints.getOrNull(1)?.vector ?: V(0.0, 0.0)

    return strokePoints
}

/** perfect-freehand's radius easing: size * (0.5 - thinning * (0.5 - pressure)). */
private fun getStrokeRadius(size: Double, thinning: Double, pressure: Double): Double =
    size * (0.5 - thinning * (0.5 - pressure))

/**
 * Stage 2: walk the resampled points, offsetting left and right by the (pressure-scaled) radius,
 * handling sharp corners and drawing round or flat caps. Returns the closed outline polygon.
 */
internal fun getStrokeOutlinePoints(
    points: List<PathPoint>,
    options: StrokeOptions,
): List<Pair<Double, Double>> {
    val size = options.size
    val smoothing = options.smoothing
    val thinning = options.thinning
    val simulatePressure = options.simulatePressure
    val capStart = options.capStart
    val capEnd = options.capEnd

    if (points.isEmpty() || size <= 0) return emptyList()

    val totalLength = points.last().runningLength
    val minDistance = (size * smoothing).pow(2)

    val leftPts = mutableListOf<V>()
    val rightPts = mutableListOf<V>()

    // Seed pressure from the first few points.
    var prevPressure = points.take(10).fold(points[0].pressure) { acc, curr ->
        var pressure = curr.pressure
        if (simulatePressure) {
            val sp = min(1.0, curr.distance / size)
            val rp = min(1.0, 1 - sp)
            pressure = min(1.0, acc + (rp - acc) * (sp * RATE_OF_PRESSURE_CHANGE))
        }
        (acc + pressure) / 2
    }

    var radius = getStrokeRadius(size, thinning, points.last().pressure)
    var firstRadius: Double? = null
    var prevVector = points[0].vector
    var pl = points[0].point
    var pr = points[0].point
    var tl = pl
    var tr = pr

    for (i in points.indices) {
        var pressure = points[i].pressure
        val point = points[i].point
        val vector = points[i].vector
        val distance = points[i].distance
        val runningLength = points[i].runningLength

        // Remove noise from the end of the line.
        if (i < points.size - 1 && totalLength - runningLength < 3) continue

        // Calculate the radius.
        radius = if (thinning != 0.0) {
            if (simulatePressure) {
                val sp = min(1.0, distance / size)
                val rp = min(1.0, 1 - sp)
                pressure = min(1.0, prevPressure + (rp - prevPressure) * (sp * RATE_OF_PRESSURE_CHANGE))
            }
            getStrokeRadius(size, thinning, pressure)
        } else {
            size / 2
        }

        if (firstRadius == null) firstRadius = radius

        // No tapering (matches default options): radius clamps to a small minimum.
        radius = max(0.01, radius)

        // Handle the last point.
        if (i == points.size - 1) {
            val offset = mul(per(vector), radius)
            leftPts.add(sub(point, offset))
            rightPts.add(add(point, offset))
            continue
        }

        val nextVector = points[i + 1].vector
        val nextDpr = dpr(vector, nextVector)

        // Handle sharp corners with a rounded cap.
        if (nextDpr < 0) {
            val offset = mul(per(prevVector), radius)
            var step = 0.0
            while (step <= 1.0) {
                tl = rotAround(sub(point, offset), point, FIXED_PI * step)
                leftPts.add(tl)
                tr = rotAround(add(point, offset), point, FIXED_PI * -step)
                rightPts.add(tr)
                step += 1.0 / 13.0
            }
            pl = tl
            pr = tr
            continue
        }

        // Add regular points, projecting to either side of the current point.
        val offset = mul(per(lrp(nextVector, vector, nextDpr)), radius)

        tl = sub(point, offset)
        if (i <= 1 || dist2(pl, tl) > minDistance) {
            leftPts.add(tl)
            pl = tl
        }

        tr = add(point, offset)
        if (i <= 1 || dist2(pr, tr) > minDistance) {
            rightPts.add(tr)
            pr = tr
        }

        prevPressure = pressure
        prevVector = vector
    }

    return assembleOutline(points, leftPts, rightPts, radius, firstRadius ?: radius, capStart, capEnd)
}

/** Draw caps and stitch the left/right offset paths into a single closed polygon. */
private fun assembleOutline(
    points: List<PathPoint>,
    leftPts: MutableList<V>,
    rightPts: MutableList<V>,
    radius: Double,
    firstRadius: Double,
    capStart: Boolean,
    capEnd: Boolean,
): List<V> {
    val firstPoint = points[0].point
    val lastPoint = if (points.size > 1) points.last().point else add(points[0].point, V(1.0, 1.0))

    // A single-point stroke becomes a dot.
    if (points.size == 1) {
        val start = prj(firstPoint, uni(per(sub(firstPoint, lastPoint))), -firstRadius)
        val dotPts = mutableListOf<V>()
        var t = 1.0 / 13.0
        while (t <= 1.0) {
            dotPts.add(rotAround(start, firstPoint, FIXED_PI * 2 * t))
            t += 1.0 / 13.0
        }
        return dotPts
    }

    val startCap = mutableListOf<V>()
    val endCap = mutableListOf<V>()

    // Start cap.
    if (capStart) {
        var t = 1.0 / 13.0
        while (t <= 1.0) {
            startCap.add(rotAround(rightPts[0], firstPoint, FIXED_PI * t))
            t += 1.0 / 13.0
        }
    } else {
        val cornersVector = sub(leftPts[0], rightPts[0])
        val offsetA = mul(cornersVector, 0.5)
        val offsetB = mul(cornersVector, 0.51)
        startCap.add(sub(firstPoint, offsetA))
        startCap.add(sub(firstPoint, offsetB))
        startCap.add(add(firstPoint, offsetB))
        startCap.add(add(firstPoint, offsetA))
    }

    // End cap.
    val direction = per(neg(points.last().vector))
    if (capEnd) {
        val start = prj(lastPoint, direction, radius)
        var t = 1.0 / 29.0
        while (t < 1.0) {
            endCap.add(rotAround(start, lastPoint, FIXED_PI * 3 * t))
            t += 1.0 / 29.0
        }
    } else {
        endCap.add(add(lastPoint, mul(direction, radius)))
        endCap.add(add(lastPoint, mul(direction, radius * 0.99)))
        endCap.add(sub(lastPoint, mul(direction, radius * 0.99)))
        endCap.add(sub(lastPoint, mul(direction, radius)))
    }

    return leftPts + endCap + rightPts.reversed() + startCap
}
