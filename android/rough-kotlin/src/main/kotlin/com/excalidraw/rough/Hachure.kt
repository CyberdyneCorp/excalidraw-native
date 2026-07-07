package com.excalidraw.rough

import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/**
 * Generates hachure (parallel line) fill segments clipped to a polygon.
 *
 * The polygon is rotated so the hachure direction is horizontal, scan lines are laid out
 * every [gap] units within the rotated bounds, each scan line is clipped against the polygon
 * edges using an even-odd rule, and the resulting segments are rotated back.
 *
 * @return a list of 2-point segments (each `[start, end]`).
 */
internal fun hachureLines(
    polygon: List<Point>,
    gap: Double,
    angleDeg: Double,
): List<List<Point>> {
    if (polygon.size < 3) return emptyList()
    val step = max(gap, 0.1)
    val angle = Math.toRadians(angleDeg)
    val cos = cos(angle)
    val sin = sin(angle)

    val rotated = polygon.map { (x, y) -> (x * cos + y * sin) to (-x * sin + y * cos) }
    val minY = rotated.minOf { it.second }
    val maxY = rotated.maxOf { it.second }

    val segments = ArrayList<List<Point>>()
    var y = minY + step
    while (y < maxY) {
        val xs = scanLineIntersections(rotated, y)
        var i = 0
        while (i + 1 < xs.size) {
            val a = unrotate(xs[i], y, cos, sin)
            val b = unrotate(xs[i + 1], y, cos, sin)
            segments.add(listOf(a, b))
            i += 2
        }
        y += step
    }
    return segments
}

private fun scanLineIntersections(rotated: List<Point>, y: Double): List<Double> {
    val xs = ArrayList<Double>()
    val n = rotated.size
    for (i in 0 until n) {
        val p1 = rotated[i]
        val p2 = rotated[(i + 1) % n]
        val y1 = p1.second
        val y2 = p2.second
        if ((y1 <= y && y2 > y) || (y2 <= y && y1 > y)) {
            val t = (y - y1) / (y2 - y1)
            xs.add(p1.first + t * (p2.first - p1.first))
        }
    }
    xs.sort()
    return xs
}

private fun unrotate(x: Double, y: Double, cos: Double, sin: Double): Point =
    (x * cos - y * sin) to (x * sin + y * cos)
