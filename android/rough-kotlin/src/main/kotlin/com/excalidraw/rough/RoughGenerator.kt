package com.excalidraw.rough

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Ports the core of rough.js: turns exact geometry into hand-drawn "sketchy" polylines,
 * plus optional hachure fill. Every shape reseeds its randomizer from [RoughOptions.seed],
 * so a given seed always produces the same output.
 */
class RoughGenerator {

    fun rectangle(x: Double, y: Double, w: Double, h: Double, options: RoughOptions = RoughOptions()): RoughShape {
        val corners = listOf(x to y, (x + w) to y, (x + w) to (y + h), x to (y + h))
        return sketchPolygon(corners, close = true, options)
    }

    fun ellipse(cx: Double, cy: Double, width: Double, height: Double, options: RoughOptions = RoughOptions()): RoughShape {
        val rng = RoughRandom(options.seed)
        val strokes = sketchEllipse(cx, cy, width, height, options, rng)
        val fills = if (options.fill) {
            hachureLines(ellipsePolygon(cx, cy, width, height), resolveGap(options), options.hachureAngle)
        } else {
            emptyList()
        }
        return RoughShape(strokes, fills)
    }

    fun line(x1: Double, y1: Double, x2: Double, y2: Double, options: RoughOptions = RoughOptions()): RoughShape {
        val rng = RoughRandom(options.seed)
        return RoughShape(doubleLine(x1, y1, x2, y2, options, rng), emptyList())
    }

    fun linearPath(points: List<Point>, close: Boolean = false, options: RoughOptions = RoughOptions()): RoughShape =
        sketchPolygon(points, close, options)

    fun polygon(points: List<Point>, options: RoughOptions = RoughOptions()): RoughShape =
        sketchPolygon(points, close = true, options)

    // --- polyline / polygon sketching -------------------------------------------------

    private fun sketchPolygon(points: List<Point>, close: Boolean, options: RoughOptions): RoughShape {
        val rng = RoughRandom(options.seed)
        val strokes = ArrayList<List<Point>>()
        for (i in 0 until points.size - 1) {
            strokes.addAll(doubleLine(points[i].first, points[i].second, points[i + 1].first, points[i + 1].second, options, rng))
        }
        if (close && points.size > 2) {
            val last = points.last()
            val first = points.first()
            strokes.addAll(doubleLine(last.first, last.second, first.first, first.second, options, rng))
        }
        val fills = if (options.fill && (close || points.size > 2)) {
            hachureLines(points, resolveGap(options), options.hachureAngle)
        } else {
            emptyList()
        }
        return RoughShape(strokes, fills)
    }

    /** A nominal segment drawn as two slightly jittered curves. */
    private fun doubleLine(x1: Double, y1: Double, x2: Double, y2: Double, o: RoughOptions, rng: RoughRandom): List<List<Point>> =
        listOf(
            sketchyLine(x1, y1, x2, y2, o, rng, overlay = false),
            sketchyLine(x1, y1, x2, y2, o, rng, overlay = true),
        )

    private fun sketchyLine(x1: Double, y1: Double, x2: Double, y2: Double, o: RoughOptions, rng: RoughRandom, overlay: Boolean): List<Point> {
        val lengthSq = distanceSq(x1, y1, x2, y2)
        val length = sqrt(lengthSq)
        val roughnessGain = when {
            length < 200 -> 1.0
            length > 500 -> 0.4
            else -> -0.0016668 * length + 1.233334
        }
        var range = MAX_RANDOMNESS_OFFSET
        if (range * range * 100 > lengthSq) range = length / 10
        val half = range / 2
        val divergePoint = 0.2 + rng.next() * 0.2
        val midDispX = offsetSym(o.bowing * MAX_RANDOMNESS_OFFSET * (y2 - y1) / 200, o, rng, roughnessGain)
        val midDispY = offsetSym(o.bowing * MAX_RANDOMNESS_OFFSET * (x1 - x2) / 200, o, rng, roughnessGain)
        val amp = if (overlay) half else range
        fun jitter() = offset(-amp, amp, o, rng, roughnessGain)

        val start = (x1 + jitter()) to (y1 + jitter())
        val c1 = (midDispX + x1 + (x2 - x1) * divergePoint + jitter()) to
            (midDispY + y1 + (y2 - y1) * divergePoint + jitter())
        val c2 = (midDispX + x1 + 2 * (x2 - x1) * divergePoint + jitter()) to
            (midDispY + y1 + 2 * (y2 - y1) * divergePoint + jitter())
        val end = (x2 + jitter()) to (y2 + jitter())
        return sampleCubic(start, c1, c2, end)
    }

    // --- ellipse ----------------------------------------------------------------------

    private fun sketchEllipse(cx: Double, cy: Double, width: Double, height: Double, o: RoughOptions, rng: RoughRandom): List<List<Point>> {
        val rxBase = abs(width / 2)
        val ryBase = abs(height / 2)
        val psq = sqrt(PI * 2 * sqrt((rxBase * rxBase + ryBase * ryBase) / 2))
        val stepCount = max(CURVE_STEP_COUNT, (CURVE_STEP_COUNT / sqrt(200.0)) * psq)
        val increment = (PI * 2) / stepCount
        val fitRandomness = 1 - CURVE_FITTING
        val rx = rxBase + offsetSym(rxBase * fitRandomness, o, rng)
        val ry = ryBase + offsetSym(ryBase * fitRandomness, o, rng)

        val overlap = increment * offset(0.1, offset(0.4, 1.0, o, rng), o, rng)
        val first = fitCurve(ellipseVertices(increment, cx, cy, rx, ry, 1.0, overlap, o, rng))
        val second = fitCurve(ellipseVertices(increment, cx, cy, rx, ry, 1.5, 0.0, o, rng))
        return listOf(first, second)
    }

    private fun ellipseVertices(
        increment: Double,
        cx: Double,
        cy: Double,
        rx: Double,
        ry: Double,
        offsetMag: Double,
        overlap: Double,
        o: RoughOptions,
        rng: RoughRandom,
    ): List<Point> {
        val radOffset = offsetSym(0.5, o, rng) - PI / 2
        val points = ArrayList<Point>()
        points.add(ellipseVertex(cx, cy, 0.9 * rx, 0.9 * ry, radOffset - increment, offsetMag, o, rng))
        var angle = radOffset
        while (angle < PI * 2 + radOffset - 0.01) {
            points.add(ellipseVertex(cx, cy, rx, ry, angle, offsetMag, o, rng))
            angle += increment
        }
        points.add(ellipseVertex(cx, cy, rx, ry, radOffset + PI * 2 + overlap * 0.5, offsetMag, o, rng))
        points.add(ellipseVertex(cx, cy, 0.98 * rx, 0.98 * ry, radOffset + overlap, offsetMag, o, rng))
        points.add(ellipseVertex(cx, cy, 0.9 * rx, 0.9 * ry, radOffset + overlap * 0.5, offsetMag, o, rng))
        return points
    }

    private fun ellipseVertex(cx: Double, cy: Double, rx: Double, ry: Double, angle: Double, offsetMag: Double, o: RoughOptions, rng: RoughRandom): Point =
        (offsetSym(offsetMag, o, rng) + cx + rx * cos(angle)) to
            (offsetSym(offsetMag, o, rng) + cy + ry * sin(angle))

    // --- fill helpers -----------------------------------------------------------------

    private fun resolveGap(o: RoughOptions): Double =
        if (o.hachureGap < 0) 4 * o.strokeWidth else o.hachureGap

    private fun ellipsePolygon(cx: Double, cy: Double, width: Double, height: Double): List<Point> {
        val rx = abs(width / 2)
        val ry = abs(height / 2)
        val steps = 48
        return (0 until steps).map { i ->
            val a = (PI * 2 * i) / steps
            (cx + rx * cos(a)) to (cy + ry * sin(a))
        }
    }

    // --- rough.js offset primitives ---------------------------------------------------

    private fun offset(min: Double, max: Double, o: RoughOptions, rng: RoughRandom, roughnessGain: Double = 1.0): Double =
        o.roughness * roughnessGain * (rng.next() * (max - min) + min)

    private fun offsetSym(x: Double, o: RoughOptions, rng: RoughRandom, roughnessGain: Double = 1.0): Double =
        offset(-x, x, o, rng, roughnessGain)

    private companion object {
        const val MAX_RANDOMNESS_OFFSET = 2.0
        const val CURVE_STEP_COUNT = 9.0
        const val CURVE_FITTING = 0.95
    }
}
