package com.excalidraw.android

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTransformGestures
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import com.excalidraw.model.ElementFactory
import com.excalidraw.model.ElementView
import kotlin.math.abs
import kotlin.math.min

@Composable
fun CanvasScreen(scene: SceneState) {
    val textMeasurer = rememberTextMeasurer()
    val renderer = remember(textMeasurer) { SceneRenderer(textMeasurer) }

    // Live preview of the shape/stroke being drawn, in scene coordinates.
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
                        when (scene.tool) {
                            Tool.SELECT -> detectTransformGestures { _, pan, zoom, _ ->
                                scene.scale = (scene.scale * zoom).coerceIn(0.1f, 10f)
                                scene.offset += pan
                            }
                            Tool.DRAW -> detectDragGestures(
                                onDragStart = { freehand = listOf(scene.toScene(it)) },
                                onDrag = { change, _ -> freehand = freehand + scene.toScene(change.position) },
                                onDragEnd = {
                                    if (freehand.size >= 2) {
                                        scene.add(
                                            ElementFactory.freedraw(
                                                freehand.map { it.x.toDouble() to it.y.toDouble() },
                                                strokeColor = "#1971c2",
                                                strokeWidth = 3.0,
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
                                    val a = dragStart
                                    val b = dragCurrent
                                    if (a != null && b != null) commitShape(scene, a, b)
                                    dragStart = null
                                    dragCurrent = null
                                },
                            )
                        }
                    },
            ) {
                withTransform({
                    translate(scene.offset.x, scene.offset.y)
                    scale(scene.scale, scene.scale, pivot = Offset.Zero)
                }) {
                    scene.elements.forEach { renderer.draw(this, ElementView(it)) }

                    // In-progress previews.
                    val a = dragStart
                    val b = dragCurrent
                    if (a != null && b != null) {
                        val left = min(a.x, b.x)
                        val top = min(a.y, b.y)
                        val size = Size(abs(b.x - a.x), abs(b.y - a.y))
                        val preview = Color(0xFF6965DB)
                        when (scene.tool) {
                            Tool.ELLIPSE -> drawOval(preview, Offset(left, top), size, style = Stroke(2f))
                            Tool.DIAMOND -> {
                                // preview as bounds box
                                drawRect(preview.copy(alpha = 0.5f), Offset(left, top), size, style = Stroke(2f))
                            }
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
    val x = min(a.x, b.x).toDouble()
    val y = min(a.y, b.y).toDouble()
    val w = abs(b.x - a.x).toDouble()
    val h = abs(b.y - a.y).toDouble()
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
            val selected = scene.tool == tool
            Button(
                onClick = { scene.tool = tool },
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (selected) Color(0xFF6965DB) else Color(0xFFE0E0E0),
                    contentColor = if (selected) Color.White else Color.Black,
                ),
            ) { Text(tool.label, maxLines = 1, softWrap = false) }
        }
        Button(
            onClick = { scene.offset = Offset.Zero; scene.scale = 1f },
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFE0E0E0), contentColor = Color.Black),
        ) { Text("Reset", maxLines = 1, softWrap = false) }
    }
}
