package com.excalidraw.rough

import kotlin.math.sqrt

/** Number of samples used when flattening a cubic bezier into a polyline. */
internal const val BEZIER_STEPS = 12

/**
 * Samples a cubic bezier (p0 -> p3, controls p1, p2) into a polyline.
 *
 * @param includeStart when false the first point (t = 0) is omitted, so segments can be
 * appended to an existing polyline without duplicating the shared vertex.
 */
internal fun sampleCubic(
    p0: Point,
    p1: Point,
    p2: Point,
    p3: Point,
    includeStart: Boolean = true,
): List<Point> {
    val out = ArrayList<Point>(BEZIER_STEPS + 1)
    val first = if (includeStart) 0 else 1
    for (i in first..BEZIER_STEPS) {
        val t = i.toDouble() / BEZIER_STEPS
        val u = 1.0 - t
        val a = u * u * u
        val b = 3 * u * u * t
        val c = 3 * u * t * t
        val d = t * t * t
        val x = a * p0.first + b * p1.first + c * p2.first + d * p3.first
        val y = a * p0.second + b * p1.second + c * p2.second + d * p3.second
        out.add(x to y)
    }
    return out
}

/**
 * Fits a smooth curve through [points] using rough.js' Catmull-Rom-style construction
 * (curveTightness = 0), returning a single flattened polyline.
 */
internal fun fitCurve(points: List<Point>): List<Point> {
    if (points.size < 4) return points.toList()
    val s = 1.0 // 1 - curveTightness, tightness defaults to 0
    val out = ArrayList<Point>()
    out.add(points[1])
    var i = 1
    while (i + 2 < points.size) {
        val p0 = points[i]
        val pPrev = points[i - 1]
        val pNext = points[i + 1]
        val pNext2 = points[i + 2]
        val c1 = (p0.first + (s * pNext.first - s * pPrev.first) / 6) to
            (p0.second + (s * pNext.second - s * pPrev.second) / 6)
        val c2 = (pNext.first + (s * p0.first - s * pNext2.first) / 6) to
            (pNext.second + (s * p0.second - s * pNext2.second) / 6)
        out.addAll(sampleCubic(p0, c1, c2, pNext, includeStart = false))
        i++
    }
    return out
}

internal fun distanceSq(x1: Double, y1: Double, x2: Double, y2: Double): Double {
    val dx = x1 - x2
    val dy = y1 - y2
    return dx * dx + dy * dy
}

internal fun distance(x1: Double, y1: Double, x2: Double, y2: Double): Double =
    sqrt(distanceSq(x1, y1, x2, y2))
