package com.excalidraw.android

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.toMutableStateList
import androidx.compose.ui.geometry.Offset
import com.excalidraw.model.ExcalidrawFile
import kotlinx.serialization.json.JsonObject

enum class Tool(val label: String) {
    SELECT("Select"),
    RECTANGLE("Rect"),
    ELLIPSE("Ellipse"),
    DIAMOND("Diamond"),
    DRAW("Draw"),
}

/**
 * Holds the editable scene plus camera and active tool. Backed by Compose
 * snapshot state so the canvas recomposes on edits. This is the app-layer view
 * of the model; the pure editor state machine (`editor` module) is a later
 * milestone per the design.
 */
class SceneState {
    val elements = mutableListOf<JsonObject>().toMutableStateList()

    var tool by mutableStateOf(Tool.SELECT)
    var offset by mutableStateOf(Offset.Zero)
    var scale by mutableStateOf(1f)

    var appState: JsonObject = JsonObject(emptyMap())
        private set
    var files: JsonObject = JsonObject(emptyMap())
        private set

    fun load(file: ExcalidrawFile) {
        elements.clear()
        elements.addAll(file.elements)
        appState = file.appState
        files = file.files
    }

    fun add(element: JsonObject) {
        elements.add(element)
    }

    fun clear() {
        elements.clear()
    }

    /** Rebuild a `.excalidraw` document from the current scene (for export). */
    fun toFile(): ExcalidrawFile =
        ExcalidrawFile(elements = elements.toList(), appState = appState, files = files)

    /** Screen point → scene point given the current camera. */
    fun toScene(screen: Offset): Offset = Offset(
        (screen.x - offset.x) / scale,
        (screen.y - offset.y) / scale,
    )
}
