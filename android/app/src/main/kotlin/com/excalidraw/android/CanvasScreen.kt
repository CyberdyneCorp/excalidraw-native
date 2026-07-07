package com.excalidraw.android

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import android.widget.Toast
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import com.excalidraw.editor.Handle
import com.excalidraw.model.ElementFactory
import com.excalidraw.model.ElementView
import kotlin.math.abs
import kotlin.math.min

private const val SELECT = "select"
private const val MOVE = "move"
private const val PAN = "pan"
private const val RESIZE = "resize"

@Composable
fun CanvasScreen(scene: SceneState) {
    val textMeasurer = rememberTextMeasurer()
    val renderer = remember(textMeasurer) { SceneRenderer(textMeasurer) }

    var dragStart by remember { mutableStateOf<Offset?>(null) }
    var dragCurrent by remember { mutableStateOf<Offset?>(null) }
    var freehand by remember { mutableStateOf<List<Offset>>(emptyList()) }

    Column(Modifier.fillMaxSize().background(Color.White)) {
        Toolbar(scene)
        Box(Modifier.fillMaxSize()) {
            Canvas(
                modifier = Modifier
                    .fillMaxSize()
                    .pointerInput(scene.tool) {
                        // Tap-to-select (a tap has no drag, so detectDragGestures never sees it).
                        if (scene.tool == Tool.SELECT) {
                            detectTapGestures(onTap = { pos -> scene.selectAtScene(scene.toScene(pos)) })
                        }
                    }
                    .pointerInput(scene.tool) {
                        when (scene.tool) {
                            Tool.SELECT -> {
                                var mode = PAN
                                var handle: Handle? = null
                                var originScene = Offset.Zero
                                detectDragGestures(
                                    onDragStart = { pos ->
                                        val sp = scene.toScene(pos)
                                        originScene = sp
                                        val h = scene.handleAt(pos, 44f)
                                        when {
                                            h != null -> { mode = RESIZE; handle = h; scene.beginTransform() }
                                            scene.hitId(sp) != null -> {
                                                scene.selectAtScene(sp); mode = MOVE; scene.beginTransform()
                                            }
                                            else -> { scene.clearSelection(); mode = PAN }
                                        }
                                    },
                                    onDrag = { change, dragAmount ->
                                        when (mode) {
                                            MOVE -> {
                                                val sp = scene.toScene(change.position)
                                                scene.translateSelection((sp.x - originScene.x).toDouble(), (sp.y - originScene.y).toDouble())
                                            }
                                            RESIZE -> {
                                                val sp = scene.toScene(change.position)
                                                handle?.let { scene.resizeSelection(it, (sp.x - originScene.x).toDouble(), (sp.y - originScene.y).toDouble()) }
                                            }
                                            else -> scene.offset += dragAmount
                                        }
                                    },
                                    onDragEnd = {
                                        if (mode == MOVE || mode == RESIZE) scene.endTransform()
                                        mode = PAN; handle = null
                                    },
                                )
                            }
                            Tool.DRAW -> detectDragGestures(
                                onDragStart = { freehand = listOf(scene.toScene(it)) },
                                onDrag = { change, _ -> freehand = freehand + scene.toScene(change.position) },
                                onDragEnd = {
                                    if (freehand.size >= 2) {
                                        scene.add(
                                            ElementFactory.freedraw(
                                                freehand.map { it.x.toDouble() to it.y.toDouble() },
                                                strokeColor = "#1971c2", strokeWidth = 3.0,
                                            ),
                                        )
                                    }
                                    freehand = emptyList()
                                },
                            )
                            else -> detectDragGestures(
                                onDragStart = { dragStart = scene.toScene(it); dragCurrent = dragStart },
                                onDrag = { change, _ -> dragCurrent = scene.toScene(change.position) },
                                onDragEnd = {
                                    val a = dragStart; val b = dragCurrent
                                    if (a != null && b != null) commitShape(scene, a, b)
                                    dragStart = null; dragCurrent = null
                                },
                            )
                        }
                    },
            ) {
                val rev = scene.revision // subscribe to editor mutations
                withTransform({
                    translate(scene.offset.x, scene.offset.y)
                    scale(scene.scale, scene.scale, pivot = Offset.Zero)
                }) {
                    scene.editor.elements.forEach { renderer.draw(this, ElementView(it)) }

                    // Selection overlay: dashed bounds + corner handles.
                    scene.selectionBounds()?.let { b ->
                        val dash = Stroke(1.5f / scene.scale, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f / scene.scale, 4f / scene.scale)))
                        drawRect(
                            Color(0xFF6965DB),
                            Offset(b.minX.toFloat(), b.minY.toFloat()),
                            Size(b.width.toFloat(), b.height.toFloat()),
                            style = dash,
                        )
                        val hs = 5f / scene.scale
                        listOf(
                            Offset(b.minX.toFloat(), b.minY.toFloat()),
                            Offset(b.maxX.toFloat(), b.minY.toFloat()),
                            Offset(b.minX.toFloat(), b.maxY.toFloat()),
                            Offset(b.maxX.toFloat(), b.maxY.toFloat()),
                        ).forEach { c ->
                            drawRect(Color.White, Offset(c.x - hs, c.y - hs), Size(hs * 2, hs * 2))
                            drawRect(Color(0xFF6965DB), Offset(c.x - hs, c.y - hs), Size(hs * 2, hs * 2), style = Stroke(1.5f / scene.scale))
                        }
                    }

                    // In-progress previews.
                    val a = dragStart; val b = dragCurrent
                    if (a != null && b != null && scene.tool != Tool.SELECT) {
                        val left = min(a.x, b.x); val top = min(a.y, b.y)
                        val size = Size(abs(b.x - a.x), abs(b.y - a.y))
                        val preview = Color(0xFF6965DB)
                        when (scene.tool) {
                            Tool.ELLIPSE -> drawOval(preview, Offset(left, top), size, style = Stroke(2f))
                            else -> drawRect(preview, Offset(left, top), size, style = Stroke(2f))
                        }
                    }
                    if (freehand.size >= 2) {
                        for (i in 1 until freehand.size) {
                            drawLine(Color(0xFF1971C2), freehand[i - 1], freehand[i], strokeWidth = 3f)
                        }
                    }
                }
            }
        }
    }
}

private fun commitShape(scene: SceneState, a: Offset, b: Offset) {
    val x = min(a.x, b.x).toDouble(); val y = min(a.y, b.y).toDouble()
    val w = abs(b.x - a.x).toDouble(); val h = abs(b.y - a.y).toDouble()
    if (w < 2 && h < 2) return
    val element = when (scene.tool) {
        Tool.ELLIPSE -> ElementFactory.ellipse(x, y, w, h, backgroundColor = "#b2f2bb")
        Tool.DIAMOND -> ElementFactory.diamond(x, y, w, h, backgroundColor = "#ffec99")
        else -> ElementFactory.rectangle(x, y, w, h, backgroundColor = "#a5d8ff")
    }
    scene.add(element)
}

@Composable
private fun Toolbar(scene: SceneState) {
    val rev = scene.revision // resubscribe so undo/redo/delete enablement updates
    Row(
        Modifier
            .fillMaxWidth()
            .background(Color(0xFFF5F5F5))
            .horizontalScroll(rememberScrollState())
            .padding(8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Tool.entries.forEach { tool ->
            ToolButton(tool.label, selected = scene.tool == tool) { scene.tool = tool }
        }
        ToolButton("Undo", enabled = scene.editor.canUndo) { scene.undo() }
        ToolButton("Redo", enabled = scene.editor.canRedo) { scene.redo() }
        ToolButton("Delete", enabled = scene.hasSelection) { scene.deleteSelection() }
        ToolButton("+") { scene.zoomBy(1.2f) }
        ToolButton("−") { scene.zoomBy(1f / 1.2f) }
        ToolButton("Reset") { scene.resetCamera() }
        val context = LocalContext.current
        ToolButton("Export") {
            val png = Exporter.exportPng(context, scene)
            val doc = Exporter.exportExcalidraw(context, scene)
            Toast.makeText(context, "Exported ${png.name} + ${doc.name}", Toast.LENGTH_SHORT).show()
        }
    }
}

@Composable
private fun ToolButton(
    label: String,
    selected: Boolean = false,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(
            containerColor = if (selected) Color(0xFF6965DB) else Color(0xFFE0E0E0),
            contentColor = if (selected) Color.White else Color.Black,
        ),
    ) { Text(label, maxLines = 1, softWrap = false) }
}
