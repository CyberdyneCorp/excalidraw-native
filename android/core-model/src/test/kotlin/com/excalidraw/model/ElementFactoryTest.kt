package com.excalidraw.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class ElementFactoryTest {

    @Test
    fun rectangleHasBaseFieldsAndDecodesBack() {
        val rect = ElementFactory.rectangle(10.0, 20.0, 100.0, 40.0, id = "r1", seed = 7)
        val view = ElementView(rect)
        assertEquals(ElementType.RECTANGLE, view.type)
        assertEquals(10.0, view.x, 0.0)
        assertEquals(100.0, view.width, 0.0)
        assertEquals("r1", view.id)
    }

    @Test
    fun freedrawStoresRelativePointsFromOrigin() {
        val pts = listOf(50.0 to 50.0, 60.0 to 70.0, 80.0 to 60.0)
        val fd = ElementFactory.freedraw(pts, id = "f1", seed = 1)
        val view = ElementView(fd)
        assertEquals(ElementType.FREEDRAW, view.type)
        assertEquals(50.0, view.x, 0.0)
        assertEquals(50.0, view.y, 0.0)
        // first relative point is the origin (0,0)
        assertEquals(0.0 to 0.0, view.points.first())
        assertEquals(30.0, view.width, 0.0) // 80 - 50
        assertEquals(20.0, view.height, 0.0) // 70 - 50
    }

    @Test
    fun createdElementSurvivesFullFileRoundTrip() {
        val file = ExcalidrawFile(elements = listOf(ElementFactory.ellipse(0.0, 0.0, 30.0, 30.0, id = "e", seed = 2)))
        val decoded = ExcalidrawFile.decode(ExcalidrawFile.encode(file))
        assertEquals(1, decoded.elements.size)
        assertEquals(ElementType.ELLIPSE, decoded.elementViews[0].type)
    }

    @Test
    fun newIdIsDeterministicForSeededRandom() {
        val a = ElementFactory.newId(Random(42))
        val b = ElementFactory.newId(Random(42))
        assertEquals(a, b)
        assertTrue(a.length == 20)
    }
}
