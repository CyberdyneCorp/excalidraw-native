package com.excalidraw.android

import android.content.Context
import android.graphics.Bitmap
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.createFontFamilyResolver
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.TextUnitType
import com.excalidraw.editor.Box
import com.excalidraw.editor.ElementGeometry
import com.excalidraw.model.ElementType
import com.excalidraw.model.ExcalidrawFile
import com.excalidraw.model.ElementView
import java.io.File

/**
 * Exports the current scene to `.excalidraw` (lossless, re-openable by the
 * iOS/web clients) and to PNG (rasterized from the same [SceneRenderer] used
 * on-screen, so the export matches what the user sees). Files are written to the
 * app's external files dir.
 */
object Exporter {

    fun exportExcalidraw(context: Context, scene: SceneState): File {
        val json = ExcalidrawFile.encode(scene.toFile())
        val out = File(context.getExternalFilesDir(null), "export.excalidraw")
        out.writeText(json)
        return out
    }

    fun exportPng(context: Context, scene: SceneState, padding: Double = 24.0): File {
        val textMeasurer = buildTextMeasurer(context)
        val views = scene.editor.elements.map(::ElementView).filterNot { it.isDeleted }
        val union = Box.union(views.map { boundsOf(it, textMeasurer) }) ?: Box(0.0, 0.0, 100.0, 100.0)
        val w = (union.width + 2 * padding).toInt().coerceIn(1, 8192)
        val h = (union.height + 2 * padding).toInt().coerceIn(1, 8192)

        val bitmap = ImageBitmap(w, h)
        val canvas = Canvas(bitmap)
        val renderer = SceneRenderer(textMeasurer)

        CanvasDrawScope().draw(Density(1f), LayoutDirection.Ltr, canvas, Size(w.toFloat(), h.toFloat())) {
            drawRect(Color.White, size = Size(w.toFloat(), h.toFloat()))
            translate((padding - union.minX).toFloat(), (padding - union.minY).toFloat()) {
                scene.editor.elements.forEach { renderer.draw(this, ElementView(it)) }
            }
        }

        val out = File(context.getExternalFilesDir(null), "export.png")
        out.outputStream().use { bitmap.asAndroidBitmap().compress(Bitmap.CompressFormat.PNG, 100, it) }
        return out
    }

    /** Bounds for export; text is measured (its model width often underestimates the rendered glyph run). */
    private fun boundsOf(v: ElementView, measurer: TextMeasurer): Box {
        val text = v.text
        if (v.type == ElementType.TEXT && text != null) {
            val layout = measurer.measure(
                text,
                TextStyle(fontSize = TextUnit(v.fontSize.toFloat(), TextUnitType.Sp)),
            )
            return Box(v.x, v.y, v.x + layout.size.width, v.y + layout.size.height)
        }
        return ElementGeometry.bounds(v)
    }

    // Density(1f) so measured text width matches the Density(1f) draw pass below.
    private fun buildTextMeasurer(context: Context): TextMeasurer =
        TextMeasurer(createFontFamilyResolver(context), Density(1f), LayoutDirection.Ltr)
}

