package com.excalidraw.freehand

import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/**
 * Minimal 2D vector helpers operating on [Pair]s of doubles, mirroring the
 * `vec` utilities used by perfect-freehand. A point/vector is (x, y).
 */
internal typealias V = Pair<Double, Double>

internal val V.x: Double get() = first
internal val V.y: Double get() = second

internal fun add(a: V, b: V): V = V(a.x + b.x, a.y + b.y)

internal fun sub(a: V, b: V): V = V(a.x - b.x, a.y - b.y)

internal fun mul(a: V, s: Double): V = V(a.x * s, a.y * s)

internal fun neg(a: V): V = V(-a.x, -a.y)

/** Perpendicular (rotate -90deg). */
internal fun per(a: V): V = V(a.y, -a.x)

/** Dot product. */
internal fun dpr(a: V, b: V): Double = a.x * b.x + a.y * b.y

internal fun len(a: V): Double = hypot(a.x, a.y)

internal fun dist(a: V, b: V): Double = hypot(a.x - b.x, a.y - b.y)

/** Squared distance. */
internal fun dist2(a: V, b: V): Double {
    val dx = a.x - b.x
    val dy = a.y - b.y
    return dx * dx + dy * dy
}

/** Unit vector; returns (0,0) for a zero-length input. */
internal fun uni(a: V): V {
    val l = len(a)
    return if (l == 0.0) V(0.0, 0.0) else mul(a, 1.0 / l)
}

internal fun isEqual(a: V, b: V): Boolean = a.x == b.x && a.y == b.y

/** Linear interpolation from [a] to [b] by [t]. */
internal fun lrp(a: V, b: V, t: Double): V = add(a, mul(sub(b, a), t))

/** Project point [a] in direction [b] (unit) by distance [c]. */
internal fun prj(a: V, b: V, c: Double): V = add(a, mul(b, c))

/** Rotate point [a] around center [c] by [r] radians. */
internal fun rotAround(a: V, c: V, r: Double): V {
    val s = sin(r)
    val co = cos(r)
    val px = a.x - c.x
    val py = a.y - c.y
    return V(px * co - py * s + c.x, px * s + py * co + c.y)
}
