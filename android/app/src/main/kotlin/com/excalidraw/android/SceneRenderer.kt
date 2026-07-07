package com.excalidraw.android

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.TextUnitType
import com.excalidraw.model.ElementType
import com.excalidraw.model.ElementView
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

/**
 * Renders `.excalidraw` elements onto a Compose [DrawScope] in scene
 * coordinates. Fills are drawn solid in this milestone; the hand-drawn
 * (rough.js / perfect-freehand) look is a later module per the design.
 */
class SceneRenderer(private val textMeasurer: TextMeasurer) {

    fun draw(scope: DrawScope, element: ElementView) {
        if (element.isDeleted) return
        val stroke = ColorUtil.parse(element.strokeColor, Color.Black)
        val fill = ColorUtil.parse(element.backgroundColor, Color.Transparent)
        val strokeStyle = Stroke(
            width = element.strokeWidth.toFloat().coerceAtLeast(1f),
            cap = StrokeCap.Round,
            join = StrokeJoin.Round,
        )
        val x = element.x.toFloat()
        val y = element.y.toFloat()
        val w = element.width.toFloat()
        val h = element.height.toFloat()

        when (element.type) {
            ElementType.RECTANGLE -> {
                if (fill.alpha > 0f) scope.drawRect(fill, Offset(x, y), Size(w, h))
                scope.drawRect(stroke, Offset(x, y), Size(w, h), style = strokeStyle)
            }
            ElementType.ELLIPSE -> {
                if (fill.alpha > 0f) scope.drawOval(fill, Offset(x, y), Size(w, h))
                scope.drawOval(stroke, Offset(x, y), Size(w, h), style = strokeStyle)
            }
            ElementType.DIAMOND -> {
                val path = diamondPath(x, y, w, h)
                if (fill.alpha > 0f) scope.drawPath(path, fill)
                scope.drawPath(path, stroke, style = strokeStyle)
            }
            ElementType.LINE, ElementType.ARROW -> {
                drawPolyline(scope, element, stroke, strokeStyle, arrow = element.type == ElementType.ARROW)
            }
            ElementType.FREEDRAW -> {
                drawFreedraw(scope, element, stroke, strokeStyle)
            }
            ElementType.TEXT -> {
                drawTextElement(scope, element, stroke)
            }
            else -> {
                // Unknown/image/frame: draw a placeholder bounds so nothing silently vanishes.
                if (w > 0f && h > 0f) {
                    scope.drawRect(stroke.copy(alpha = 0.4f), Offset(x, y), Size(w, h), style = strokeStyle)
                }
            }
        }
    }

    private fun diamondPath(x: Float, y: Float, w: Float, h: Float): Path = Path().apply {
        moveTo(x + w / 2f, y)
        lineTo(x + w, y + h / 2f)
        lineTo(x + w / 2f, y + h)
        lineTo(x, y + h / 2f)
        close()
    }

    private fun drawPolyline(
        scope: DrawScope,
        element: ElementView,
        stroke: Color,
        strokeStyle: Stroke,
        arrow: Boolean,
    ) {
        val pts = element.points
        if (pts.size < 2) return
        val ox = element.x.toFloat()
        val oy = element.y.toFloat()
        val abs = pts.map { Offset(ox + it.first.toFloat(), oy + it.second.toFloat()) }
        val path = Path().apply {
            moveTo(abs.first().x, abs.first().y)
            abs.drop(1).forEach { lineTo(it.x, it.y) }
        }
        scope.drawPath(path, stroke, style = strokeStyle)
        if (arrow) {
            val end = abs.last()
            val prev = abs[abs.size - 2]
            val angle = atan2((end.y - prev.y).toDouble(), (end.x - prev.x).toDouble())
            val headLen = 16f
            val spread = Math.toRadians(25.0)
            for (s in listOf(angle - spread, angle + spread)) {
                val hx = end.x - headLen * cos(s).toFloat()
                val hy = end.y - headLen * sin(s).toFloat()
                scope.drawLine(stroke, end, Offset(hx, hy), strokeWidth = strokeStyle.width, cap = StrokeCap.Round)
            }
        }
    }

    private fun drawFreedraw(
        scope: DrawScope,
        element: ElementView,
        stroke: Color,
        strokeStyle: Stroke,
    ) {
        val pts = element.points
        if (pts.isEmpty()) return
        val ox = element.x.toFloat()
        val oy = element.y.toFloat()
        if (pts.size == 1) {
            scope.drawCircle(stroke, strokeStyle.width, Offset(ox, oy))
            return
        }
        val path = Path().apply {
            moveTo(ox + pts.first().first.toFloat(), oy + pts.first().second.toFloat())
            pts.drop(1).forEach { lineTo(ox + it.first.toFloat(), oy + it.second.toFloat()) }
        }
        scope.drawPath(path, stroke, style = strokeStyle)
    }

    private fun drawTextElement(scope: DrawScope, element: ElementView, stroke: Color) {
        val content = element.text ?: return
        val layout: TextLayoutResult = textMeasurer.measure(
            text = content,
            style = TextStyle(
                color = stroke,
                fontSize = TextUnit(element.fontSize.toFloat(), TextUnitType.Sp),
            ),
        )
        scope.drawText(layout, topLeft = Offset(element.x.toFloat(), element.y.toFloat()))
    }

    companion object {
        /** Axis-aligned bounds of an element in scene space (best-effort). */
        fun bounds(element: ElementView): Rect {
            val x = element.x.toFloat()
            val y = element.y.toFloat()
            return Rect(x, y, x + element.width.toFloat(), y + element.height.toFloat())
        }
    }
}
