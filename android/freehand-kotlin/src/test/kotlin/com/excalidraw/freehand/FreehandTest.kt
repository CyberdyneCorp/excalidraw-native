package com.excalidraw.freehand

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FreehandTest {

    private fun boundingBox(pts: List<Pair<Double, Double>>): Pair<Double, Double> {
        val xs = pts.map { it.first }
        val ys = pts.map { it.second }
        val width = (xs.maxOrNull()!! - xs.minOrNull()!!)
        val height = (ys.maxOrNull()!! - ys.minOrNull()!!)
        return width to height
    }

    private fun horizontalLine(n: Int, pressure: Double): List<StrokePoint> =
        (0 until n).map { StrokePoint(it * 10.0, 0.0, pressure) }

    @Test
    fun emptyInputReturnsEmptyWithoutThrowing() {
        val outline = getStroke(emptyList())
        assertTrue("expected empty outline for empty input", outline.isEmpty())
    }

    @Test
    fun singlePointYieldsNonEmptyDot() {
        val outline = getStroke(listOf(StrokePoint(50.0, 50.0, 0.5)))
        assertTrue("expected a non-empty dot polygon", outline.isNotEmpty())

        val (w, h) = boundingBox(outline)
        // The dot should have some spatial extent in both dimensions.
        assertTrue("dot should have positive width", w > 0.0)
        assertTrue("dot should have positive height", h > 0.0)
    }

    @Test
    fun straightLineProducesVariableWidthBand() {
        val size = 16.0
        val outline = getStroke(
            horizontalLine(20, 0.5),
            StrokeOptions(size = size, simulatePressure = false),
        )
        assertTrue("expected a non-empty outline", outline.isNotEmpty())

        val (width, height) = boundingBox(outline)
        // The band should be much longer than it is tall.
        assertTrue("band should span the path length", width > 100.0)
        // Height should be on the order of `size` (a band, not a hairline or a huge blob).
        assertTrue("band height ($height) should be on the order of size", height in (size * 0.25)..(size * 2.0))
    }

    @Test
    fun higherPressureYieldsWiderBandThanLowerPressure() {
        val opts = StrokeOptions(size = 16.0, thinning = 0.6, simulatePressure = false)

        val low = getStroke(horizontalLine(20, 0.2), opts)
        val high = getStroke(horizontalLine(20, 0.9), opts)

        val lowHeight = boundingBox(low).second
        val highHeight = boundingBox(high).second

        assertTrue("both outlines should be non-empty", low.isNotEmpty() && high.isNotEmpty())
        assertTrue(
            "higher pressure ($highHeight) should be wider than lower pressure ($lowHeight)",
            highHeight > lowHeight,
        )
    }

    @Test
    fun outlineIsClosedPolygonWithManyVertices() {
        val outline = getStroke(horizontalLine(10, 0.5), StrokeOptions(simulatePressure = false))
        // A closed variable-width band with round caps should have plenty of vertices.
        assertTrue("expected a rich polygon", outline.size >= 8)
    }

    @Test
    fun twoPointStrokeDoesNotThrowAndIsNonEmpty() {
        val outline = getStroke(listOf(StrokePoint(0.0, 0.0), StrokePoint(100.0, 0.0)))
        assertEquals(false, outline.isEmpty())
    }
}
