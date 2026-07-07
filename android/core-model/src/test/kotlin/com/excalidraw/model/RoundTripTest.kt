package com.excalidraw.model

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RoundTripTest {

    private val sample = """
        {
          "type": "excalidraw",
          "version": 2,
          "source": "https://excalidraw.com",
          "elements": [
            {
              "id": "rect-1",
              "type": "rectangle",
              "x": 100.0, "y": 120.0, "width": 200.0, "height": 80.0,
              "angle": 0, "strokeColor": "#1e1e1e", "backgroundColor": "#a5d8ff",
              "fillStyle": "solid", "strokeWidth": 2, "roughness": 1, "opacity": 100,
              "seed": 12345,
              "customData": { "authoredOn": "ios", "note": "keep me" }
            },
            {
              "id": "arrow-1",
              "type": "arrow",
              "x": 320.0, "y": 160.0, "width": 120.0, "height": 0.0,
              "points": [[0,0],[120,0]],
              "startBinding": { "elementId": "rect-1" }
            }
          ],
          "appState": { "viewBackgroundColor": "#ffffff", "customFlag": true },
          "files": {}
        }
    """.trimIndent()

    @Test
    fun decodesLenientlyAndExposesTypedFields() {
        val file = ExcalidrawFile.decode(sample)
        assertEquals(2, file.elements.size)
        val rect = file.elementViews[0]
        assertEquals(ElementType.RECTANGLE, rect.type)
        assertEquals(100.0, rect.x, 0.0001)
        assertEquals(200.0, rect.width, 0.0001)
        assertEquals("#a5d8ff", rect.backgroundColor)
        assertFalse(rect.isDeleted)

        val arrow = file.elementViews[1]
        assertEquals(ElementType.ARROW, arrow.type)
        assertEquals(2, arrow.points.size)
        assertEquals(120.0 to 0.0, arrow.points[1])
    }

    @Test
    fun toleratesArrowBindingWithoutFixedPointOrMode() {
        // Mirrors the iOS regression: a binding carrying only elementId (agent
        // connectors, upstream focus/gap bindings) must not fail the whole decode.
        val file = ExcalidrawFile.decode(sample)
        val arrow = file.elementViews[1]
        assertEquals(ElementType.ARROW, arrow.type)
        // The whole scene still decoded — both elements are present.
        assertEquals(2, file.elements.size)
    }

    @Test
    fun missingKeysFallBackToDefaults() {
        val partial = """{ "elements": [ { "id": "x", "type": "ellipse" } ] }"""
        val file = ExcalidrawFile.decode(partial)
        assertEquals("excalidraw", file.type)
        assertEquals(1, file.elements.size)
        val e = file.elementViews[0]
        assertEquals(ElementType.ELLIPSE, e.type)
        assertEquals(0.0, e.x, 0.0001)
        assertEquals("#1e1e1e", e.strokeColor)
    }

    @Test
    fun unmodelledDataSurvivesRoundTrip() {
        val file = ExcalidrawFile.decode(sample)
        val encoded = ExcalidrawFile.encode(file)
        val reparsed = Json.parseToJsonElement(encoded).jsonObject

        // Element customData survives.
        val elements = reparsed["elements"]!!
        val rect = (elements as kotlinx.serialization.json.JsonArray)[0].jsonObject
        val customData = rect["customData"]!!.jsonObject
        assertEquals("\"ios\"", customData["authoredOn"].toString())
        assertNotNull(customData["note"])

        // Unknown appState keys survive.
        val appState = reparsed["appState"]!!.jsonObject
        assertTrue(appState.containsKey("customFlag"))
        assertTrue(appState.containsKey("viewBackgroundColor"))
    }

    @Test
    fun semanticRoundTripIsStable() {
        val file = ExcalidrawFile.decode(sample)
        val once = ExcalidrawFile.encode(file)
        val twice = ExcalidrawFile.encode(ExcalidrawFile.decode(once))
        assertEquals(
            Json.parseToJsonElement(once),
            Json.parseToJsonElement(twice),
        )
    }
}
