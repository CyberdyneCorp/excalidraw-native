package com.excalidraw.android

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
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
import com.excalidraw.freehand.StrokePoint
import com.excalidraw.freehand.getStroke
import com.excalidraw.model.ElementType
import com.excalidraw.model.ElementView
import com.excalidraw.rough.RoughGenerator
import com.excalidraw.rough.RoughOptions
import com.excalidraw.rough.RoughShape
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/**
 * Renders `.excalidraw` elements onto a Compose [DrawScope] in scene
 * coordinates using the Kotlin rough.js port for the hand-drawn look (sketchy
 * strokes + hachure fills) and the perfect-freehand port for ink strokes. Text
 * stays on the Compose text layer so it is crisp at any zoom.
 */
class SceneRenderer(private val textMeasurer: TextMeasurer) {

    private val rough = RoughGenerator()

    fun draw(scope: DrawScope, element: ElementView) {
        if (element.isDeleted) return
        val stroke = ColorUtil.parse(element.strokeColor, Color.Black)
        val fill = ColorUtil.parse(element.backgroundColor, Color.Transparent)
        val x = element.x
        val y = element.y
        val w = element.width
        val h = element.height
        val opts = RoughOptions(
            roughness = element.roughness,
            seed = element.seed,
            strokeWidth = element.strokeWidth,
            fill = fill.alpha > 0f,
            fillStyle = element.fillStyle,
        )

        when (element.type) {
            ElementType.RECTANGLE ->
                drawRough(scope, rough.rectangle(x, y, w, h, opts), stroke, fill, element.strokeWidth)

            ElementType.ELLIPSE ->
                drawRough(scope, rough.ellipse(x + w / 2, y + h / 2, w, h, opts), stroke, fill, element.strokeWidth)

            ElementType.DIAMOND -> {
                val pts = listOf(
                    (x + w / 2) to y,
                    (x + w) to (y + h / 2),
                    (x + w / 2) to (y + h),
                    x to (y + h / 2),
                )
                drawRough(scope, rough.polygon(pts, opts), stroke, fill, element.strokeWidth)
            }

            ElementType.LINE, ElementType.ARROW -> {
                val abs = element.points.map { (x + it.first) to (y + it.second) }
                if (abs.size >= 2) {
                    drawRough(scope, rough.linearPath(abs, close = false, opts), stroke, fill, element.strokeWidth)
                    if (element.type == ElementType.ARROW) drawArrowhead(scope, abs, stroke, element.strokeWidth)
                }
            }

            ElementType.FREEDRAW -> drawFreedraw(scope, element, stroke)

            ElementType.TEXT -> drawTextElement(scope, element, stroke)

            else -> if (w > 0 && h > 0) {
                scope.drawRect(
                    stroke.copy(alpha = 0.4f),
                    Offset(x.toFloat(), y.toFloat()),
                    androidx.compose.ui.geometry.Size(w.toFloat(), h.toFloat()),
                    style = Stroke(1f),
                )
            }
        }
    }

    private fun drawRough(
        scope: DrawScope,
        shape: RoughShape,
        stroke: Color,
        fill: Color,
        strokeWidth: Double,
    ) {
        if (fill.alpha > 0f) {
            val fillWeight = max(1f, (strokeWidth * 0.5).toFloat())
            for (seg in shape.fillPaths) {
                if (seg.size >= 2) {
                    scope.drawLine(
                        fill,
                        Offset(seg[0].first.toFloat(), seg[0].second.toFloat()),
                        Offset(seg[1].first.toFloat(), seg[1].second.toFloat()),
                        strokeWidth = fillWeight,
                        cap = StrokeCap.Round,
                    )
                }
            }
        }
        val strokeStyle = Stroke(max(1f, strokeWidth.toFloat()), cap = StrokeCap.Round, join = StrokeJoin.Round)
        for (path in shape.strokePaths) {
            if (path.size < 2) continue
            val p = Path().apply {
                moveTo(path.first().first.toFloat(), path.first().second.toFloat())
                path.drop(1).forEach { lineTo(it.first.toFloat(), it.second.toFloat()) }
            }
            scope.drawPath(p, stroke, style = strokeStyle)
        }
    }

    private fun drawArrowhead(scope: DrawScope, abs: List<Pair<Double, Double>>, stroke: Color, strokeWidth: Double) {
        val end = abs.last()
        val prev = abs[abs.size - 2]
        val angle = atan2(end.second - prev.second, end.first - prev.first)
        val headLen = 16.0
        val spread = Math.toRadians(25.0)
        val endO = Offset(end.first.toFloat(), end.second.toFloat())
        for (s in listOf(angle - spread, angle + spread)) {
            val hx = (end.first - headLen * cos(s)).toFloat()
            val hy = (end.second - headLen * sin(s)).toFloat()
            scope.drawLine(stroke, endO, Offset(hx, hy), strokeWidth = max(1f, strokeWidth.toFloat()), cap = StrokeCap.Round)
        }
    }

    private fun drawFreedraw(scope: DrawScope, element: ElementView, stroke: Color) {
        val pts = element.points
        if (pts.isEmpty()) return
        val ox = element.x
        val oy = element.y
        val input = pts.map { StrokePoint(ox + it.first, oy + it.second, 0.5) }
        val outline = getStroke(
            input,
            com.excalidraw.freehand.StrokeOptions(size = max(6.0, element.strokeWidth * 4.5)),
        )
        if (outline.size < 3) {
            scope.drawCircle(stroke, max(1f, element.strokeWidth.toFloat()), Offset(ox.toFloat(), oy.toFloat()))
            return
        }
        val path = Path().apply {
            moveTo(outline.first().first.toFloat(), outline.first().second.toFloat())
            outline.drop(1).forEach { lineTo(it.first.toFloat(), it.second.toFloat()) }
            close()
        }
        scope.drawPath(path, stroke)
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
        fun bounds(element: ElementView): Rect {
            val x = element.x.toFloat()
            val y = element.y.toFloat()
            return Rect(x, y, x + element.width.toFloat(), y + element.height.toFloat())
        }
    }
}
