package com.excalidraw.rough

/** A 2D point. */
typealias Point = Pair<Double, Double>

/**
 * Options controlling the hand-drawn look, mirroring rough.js defaults.
 *
 * @param roughness how much the sketchy strokes deviate from the true geometry (0 = precise).
 * @param bowing how much straight segments bow out into curves.
 * @param seed seed for the deterministic randomizer; same seed => same shape.
 * @param strokeWidth nominal stroke width (drives the default hachure gap).
 * @param fill whether to generate hachure fill lines.
 * @param fillStyle fill style (only "hachure" is implemented; other values fall back to hachure).
 * @param hachureGap spacing between hachure lines; when < 0 defaults to 4 * strokeWidth.
 * @param hachureAngle angle of the hachure lines, in degrees.
 * @param fillWeight width of hachure lines; when < 0 defaults to strokeWidth / 2 (informational only).
 */
data class RoughOptions(
    val roughness: Double = 1.0,
    val bowing: Double = 1.0,
    val seed: Long = 1L,
    val strokeWidth: Double = 1.0,
    val fill: Boolean = false,
    val fillStyle: String = "hachure",
    val hachureGap: Double = -1.0,
    val hachureAngle: Double = -41.0,
    val fillWeight: Double = -1.0,
)

/**
 * The result of sketching a shape.
 *
 * @param strokePaths sketchy outline polylines (each a list of points).
 * @param fillPaths hachure fill line segments (each a 2-point list).
 */
data class RoughShape(
    val strokePaths: List<List<Point>>,
    val fillPaths: List<List<Point>>,
)
