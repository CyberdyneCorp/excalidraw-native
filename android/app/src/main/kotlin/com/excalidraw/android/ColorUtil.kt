package com.excalidraw.android

import androidx.compose.ui.graphics.Color

/** Parses Excalidraw color strings (`#rrggbb`, `#rgb`, `transparent`). */
object ColorUtil {
    fun parse(value: String, fallback: Color = Color.Transparent): Color {
        val v = value.trim()
        if (v.equals("transparent", ignoreCase = true) || v.isEmpty()) return Color.Transparent
        if (!v.startsWith("#")) return fallback
        val hex = v.substring(1)
        return try {
            when (hex.length) {
                3 -> {
                    val r = hex[0].digitToInt(16) * 17
                    val g = hex[1].digitToInt(16) * 17
                    val b = hex[2].digitToInt(16) * 17
                    Color(r, g, b)
                }
                6 -> Color(
                    hex.substring(0, 2).toInt(16),
                    hex.substring(2, 4).toInt(16),
                    hex.substring(4, 6).toInt(16),
                )
                8 -> Color(
                    hex.substring(0, 2).toInt(16),
                    hex.substring(2, 4).toInt(16),
                    hex.substring(4, 6).toInt(16),
                    hex.substring(6, 8).toInt(16),
                )
                else -> fallback
            }
        } catch (_: NumberFormatException) {
            fallback
        }
    }
}
