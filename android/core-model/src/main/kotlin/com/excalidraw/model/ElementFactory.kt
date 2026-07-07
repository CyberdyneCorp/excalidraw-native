package com.excalidraw.model

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlin.random.Random

/**
 * Builds new `.excalidraw` element objects with the base fields the format
 * expects, so freshly drawn elements interoperate with the other clients. Ids
 * and seeds are injected (defaulting to random) to keep this deterministic in
 * tests.
 */
object ElementFactory {

    private const val ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

    fun newId(random: Random = Random.Default): String =
        (1..20).map { ALPHABET[random.nextInt(ALPHABET.length)] }.joinToString("")

    private fun base(
        type: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        strokeColor: String,
        backgroundColor: String,
        strokeWidth: Double,
        roughness: Double,
        id: String,
        seed: Long,
        extra: Map<String, kotlinx.serialization.json.JsonElement> = emptyMap(),
    ): JsonObject = JsonObject(
        buildMap {
            put("id", JsonPrimitive(id))
            put("type", JsonPrimitive(type))
            put("x", JsonPrimitive(x))
            put("y", JsonPrimitive(y))
            put("width", JsonPrimitive(width))
            put("height", JsonPrimitive(height))
            put("angle", JsonPrimitive(0.0))
            put("strokeColor", JsonPrimitive(strokeColor))
            put("backgroundColor", JsonPrimitive(backgroundColor))
            put("fillStyle", JsonPrimitive("solid"))
            put("strokeWidth", JsonPrimitive(strokeWidth))
            put("strokeStyle", JsonPrimitive("solid"))
            put("roughness", JsonPrimitive(roughness))
            put("opacity", JsonPrimitive(100.0))
            put("seed", JsonPrimitive(seed))
            put("groupIds", JsonArray(emptyList()))
            put("isDeleted", JsonPrimitive(false))
            putAll(extra)
        },
    )

    fun rectangle(
        x: Double, y: Double, width: Double, height: Double,
        strokeColor: String = "#1e1e1e", backgroundColor: String = "transparent",
        strokeWidth: Double = 2.0, roughness: Double = 1.0,
        id: String = newId(), seed: Long = Random.nextLong(1, Int.MAX_VALUE.toLong()),
    ): JsonObject = base("rectangle", x, y, width, height, strokeColor, backgroundColor, strokeWidth, roughness, id, seed)

    fun ellipse(
        x: Double, y: Double, width: Double, height: Double,
        strokeColor: String = "#1e1e1e", backgroundColor: String = "transparent",
        strokeWidth: Double = 2.0, roughness: Double = 1.0,
        id: String = newId(), seed: Long = Random.nextLong(1, Int.MAX_VALUE.toLong()),
    ): JsonObject = base("ellipse", x, y, width, height, strokeColor, backgroundColor, strokeWidth, roughness, id, seed)

    fun diamond(
        x: Double, y: Double, width: Double, height: Double,
        strokeColor: String = "#1e1e1e", backgroundColor: String = "transparent",
        strokeWidth: Double = 2.0, roughness: Double = 1.0,
        id: String = newId(), seed: Long = Random.nextLong(1, Int.MAX_VALUE.toLong()),
    ): JsonObject = base("diamond", x, y, width, height, strokeColor, backgroundColor, strokeWidth, roughness, id, seed)

    /** Freedraw element from absolute points; stores origin at the first point. */
    fun freedraw(
        points: List<Pair<Double, Double>>,
        strokeColor: String = "#1e1e1e", strokeWidth: Double = 2.0,
        id: String = newId(), seed: Long = Random.nextLong(1, Int.MAX_VALUE.toLong()),
    ): JsonObject {
        require(points.isNotEmpty()) { "freedraw needs at least one point" }
        val ox = points.first().first
        val oy = points.first().second
        val rel = points.map { (px, py) ->
            JsonArray(listOf(JsonPrimitive(px - ox), JsonPrimitive(py - oy)))
        }
        val xs = points.map { it.first }
        val ys = points.map { it.second }
        return base(
            "freedraw", ox, oy,
            (xs.max() - xs.min()), (ys.max() - ys.min()),
            strokeColor, "transparent", strokeWidth, 1.0, id, seed,
            extra = mapOf("points" to JsonArray(rel)),
        )
    }
}
