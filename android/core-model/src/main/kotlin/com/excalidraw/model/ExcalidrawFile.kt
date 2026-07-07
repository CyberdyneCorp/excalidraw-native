package com.excalidraw.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/**
 * The top-level `.excalidraw` document.
 *
 * Elements and appState are kept as raw [JsonObject]s so that unmodelled data
 * (element `customData`, unknown app-state keys) survives a decode/encode
 * round-trip unchanged — the same lossless-preservation contract the Swift core
 * guarantees (see the `data-model` capability spec). Typed access to the fields
 * the renderer needs is provided by [ElementView].
 */
@Serializable
data class ExcalidrawFile(
    val type: String = "excalidraw",
    val version: Int = 2,
    val source: String = "https://excalidraw.com",
    val elements: List<JsonObject> = emptyList(),
    val appState: JsonObject = JsonObject(emptyMap()),
    val files: JsonObject = JsonObject(emptyMap()),
) {
    /** Typed, render-oriented views over the raw element objects. */
    val elementViews: List<ElementView> get() = elements.map(::ElementView)

    companion object {
        /**
         * Lenient JSON: unknown keys are ignored for typed decode but preserved
         * in the raw [JsonObject]s; missing keys fall back to defaults so older
         * or partial files still load rather than failing.
         */
        val json: Json = Json {
            ignoreUnknownKeys = true
            isLenient = true
            explicitNulls = false
            encodeDefaults = true
        }

        /** Decode a `.excalidraw` document string. Never throws on missing keys. */
        fun decode(text: String): ExcalidrawFile = json.decodeFromString(serializer(), text)

        /** Encode back to a `.excalidraw` document string. */
        fun encode(file: ExcalidrawFile): String = json.encodeToString(serializer(), file)
    }
}
