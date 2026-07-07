package com.excalidraw.rough

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class RoughGeneratorTest {

    private val gen = RoughGenerator()

    @Test
    fun `same seed produces identical stroke paths`() {
        val opts = RoughOptions(seed = 42L)
        val a = gen.rectangle(10.0, 20.0, 100.0, 60.0, opts)
        val b = gen.rectangle(10.0, 20.0, 100.0, 60.0, opts)
        assertEquals(a.strokePaths, b.strokePaths)
    }

    @Test
    fun `different seeds produce different stroke paths`() {
        val a = gen.rectangle(0.0, 0.0, 100.0, 100.0, RoughOptions(seed = 1L))
        val b = gen.rectangle(0.0, 0.0, 100.0, 100.0, RoughOptions(seed = 2L))
        assertTrue(a.strokePaths != b.strokePaths)
    }

    @Test
    fun `deterministic RNG matches Park-Miller sequence`() {
        val rng = RoughRandom(1L)
        // state starts at 1: next state = 48271, value = 48271 / 2^31
        assertEquals(48271.0 / 2147483648.0, rng.next(), 1e-15)
        val expectedSecond = (48271L * 48271L % 2147483647L).toDouble() / 2147483648.0
        assertEquals(expectedSecond, rng.next(), 1e-15)
    }

    @Test
    fun `zero roughness keeps outline near the true corners`() {
        val x = 5.0
        val y = 7.0
        val w = 120.0
        val h = 80.0
        val shape = gen.rectangle(x, y, w, h, RoughOptions(roughness = 0.0))
        val corners = listOf(x to y, (x + w) to y, (x + w) to (y + h), x to (y + h))
        val allPoints = shape.strokePaths.flatten()
        for (corner in corners) {
            val nearest = allPoints.minOf { p -> abs(p.first - corner.first) + abs(p.second - corner.second) }
            assertTrue("no stroke point near corner $corner (nearest=$nearest)", nearest < 1e-6)
        }
    }

    @Test
    fun `hachure fill on filled rectangle produces multiple segments within bounds`() {
        val x = 0.0
        val y = 0.0
        val w = 100.0
        val h = 100.0
        val shape = gen.rectangle(x, y, w, h, RoughOptions(fill = true, strokeWidth = 2.0))
        assertTrue("expected multiple fill segments, got ${shape.fillPaths.size}", shape.fillPaths.size >= 3)
        val eps = 1e-6
        for (seg in shape.fillPaths) {
            assertEquals(2, seg.size)
            for ((px, py) in seg) {
                assertTrue("x=$px out of bounds", px >= x - eps && px <= x + w + eps)
                assertTrue("y=$py out of bounds", py >= y - eps && py <= y + h + eps)
            }
        }
    }

    @Test
    fun `ellipse returns a closed-ish stroke polyline with many vertices`() {
        val shape = gen.ellipse(50.0, 50.0, 120.0, 80.0)
        assertTrue("expected stroke polylines", shape.strokePaths.isNotEmpty())
        val longest = shape.strokePaths.maxByOrNull { it.size }!!
        assertTrue("expected many vertices, got ${longest.size}", longest.size >= 20)
        // closed-ish: last vertex should return near the first
        val start = longest.first()
        val end = longest.last()
        val gap = abs(start.first - end.first) + abs(start.second - end.second)
        val span = 120.0
        assertTrue("polyline not closed-ish (gap=$gap)", gap < span * 0.5)
    }

    @Test
    fun `hachure fill clipped to ellipse stays inside bounding box`() {
        val cx = 60.0
        val cy = 40.0
        val w = 100.0
        val h = 60.0
        val shape = gen.ellipse(cx, cy, w, h, RoughOptions(fill = true, strokeWidth = 2.0))
        assertTrue(shape.fillPaths.isNotEmpty())
        val eps = 1e-6
        for (seg in shape.fillPaths) {
            for ((px, py) in seg) {
                assertTrue(px >= cx - w / 2 - eps && px <= cx + w / 2 + eps)
                assertTrue(py >= cy - h / 2 - eps && py <= cy + h / 2 + eps)
            }
        }
    }

    @Test
    fun `line produces two jittered curves`() {
        val shape = gen.line(0.0, 0.0, 100.0, 0.0)
        assertEquals(2, shape.strokePaths.size)
        assertTrue(shape.fillPaths.isEmpty())
    }

    @Test
    fun `polygon closes the outline`() {
        val pts = listOf(0.0 to 0.0, 50.0 to 0.0, 25.0 to 40.0)
        val shape = gen.polygon(pts, RoughOptions(seed = 3L))
        // three edges, each two jittered curves
        assertEquals(6, shape.strokePaths.size)
        // sanity: nearest stroke point to the min-distance is finite
        assertTrue(shape.strokePaths.all { it.size >= 2 })
    }
}
