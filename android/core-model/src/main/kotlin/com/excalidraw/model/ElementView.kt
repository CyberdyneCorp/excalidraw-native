package com.excalidraw.model

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive

/** The element kinds Excalidraw supports, mapped from the flat `type` field. */
enum class ElementType {
    RECTANGLE, ELLIPSE, DIAMOND, LINE, ARROW, FREEDRAW, TEXT, IMAGE, FRAME, UNKNOWN;

    companion object {
        fun from(raw: String?): ElementType = when (raw) {
            "rectangle" -> RECTANGLE
            "ellipse" -> ELLIPSE
            "diamond" -> DIAMOND
            "line" -> LINE
            "arrow" -> ARROW
            "freedraw" -> FREEDRAW
            "text" -> TEXT
            "image" -> IMAGE
            "frame" -> FRAME
            else -> UNKNOWN
        }
    }
}

/**
 * A read-only typed view over a raw element [JsonObject]. Keeping the underlying
 * object as the source of truth means the renderer reads what it understands
 * while unmodelled fields ride along untouched for round-trip fidelity.
 */
class ElementView(val raw: JsonObject) {
    private fun num(key: String): Double? =
        (raw[key] as? JsonPrimitive)?.doubleOrNull

    private fun str(key: String): String? =
        (raw[key] as? JsonPrimitive)?.takeIf { it.isString }?.content

    val id: String get() = str("id") ?: ""
    val type: ElementType get() = ElementType.from(str("type"))
    val x: Double get() = num("x") ?: 0.0
    val y: Double get() = num("y") ?: 0.0
    val width: Double get() = num("width") ?: 0.0
    val height: Double get() = num("height") ?: 0.0
    val angle: Double get() = num("angle") ?: 0.0
    val strokeColor: String get() = str("strokeColor") ?: "#1e1e1e"
    val backgroundColor: String get() = str("backgroundColor") ?: "transparent"
    val fillStyle: String get() = str("fillStyle") ?: "solid"
    val strokeWidth: Double get() = num("strokeWidth") ?: 1.0
    val roughness: Double get() = num("roughness") ?: 1.0
    val opacity: Double get() = num("opacity") ?: 100.0
    val seed: Long get() = num("seed")?.toLong() ?: 1L
    val isDeleted: Boolean get() = (raw["isDeleted"] as? JsonPrimitive)?.booleanOrNull ?: false
    val text: String? get() = str("text")
    val fontSize: Double get() = num("fontSize") ?: 20.0

    /** Relative points for line/arrow/freedraw, as `[dx, dy]` pairs from (x, y). */
    val points: List<Pair<Double, Double>>
        get() = (raw["points"] as? kotlinx.serialization.json.JsonArray)?.mapNotNull { p ->
            val arr = (p as? kotlinx.serialization.json.JsonArray) ?: return@mapNotNull null
            if (arr.size < 2) return@mapNotNull null
            val dx = arr[0].jsonPrimitive.doubleOrNull ?: return@mapNotNull null
            val dy = arr[1].jsonPrimitive.doubleOrNull ?: return@mapNotNull null
            dx to dy
        } ?: emptyList()
}
