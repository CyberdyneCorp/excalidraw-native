package com.excalidraw.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.remember
import com.excalidraw.model.ExcalidrawFile

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val sample = runCatching {
            assets.open("sample.excalidraw").bufferedReader().use { it.readText() }
        }.getOrNull()

        setContent {
            val scene = remember {
                SceneState().apply {
                    sample?.let { load(ExcalidrawFile.decode(it)) }
                    // Center the seed scene a little for first paint.
                    offset = androidx.compose.ui.geometry.Offset(20f, 20f)
                }
            }
            CanvasScreen(scene)
        }
    }
}
