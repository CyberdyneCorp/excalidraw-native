import ExcalidrawMath
import ExcalidrawModel
import ExcalidrawRender
import XCTest
@testable import ExcalidrawMetal

/// Pure-logic coverage for the scene → triangle builder: fills, arrowheads,
/// rotation, opacity and theming, none of which need a GPU.
final class SceneGeometryTests: XCTestCase {
    private func base(_ id: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double) -> BaseProperties {
        var b = BaseProperties(id: id); b.x = x; b.y = y; b.width = w; b.height = h; b.seed = 7
        b.strokeColor = "#1e1e1e"
        return b
    }

    private func geometry(_ elements: [ExcalidrawElement], theme: Theme = .light) -> SceneGeometry {
        SceneGeometry(scene: Scene(elements: elements), theme: theme)
    }

    func testSolidFillEmitsTriangles() {
        var rect = base("r", 10, 10, 100, 60)
        rect.backgroundColor = "#ffc9c9"; rect.fillStyle = .solid
        let g = geometry([ExcalidrawElement(base: rect, kind: .rectangle)])
        XCTAssertGreaterThan(g.triangleCount, 0)
        XCTAssertTrue(g.handledIDs.contains("r"))
    }

    func testHachureFillEmitsStrokeTriangles() {
        var rect = base("r", 10, 10, 100, 60)
        rect.backgroundColor = "#ffc9c9"; rect.fillStyle = .hachure
        let g = geometry([ExcalidrawElement(base: rect, kind: .rectangle)])
        XCTAssertGreaterThan(g.triangleCount, 0)
    }

    func testTransparentFillEmitsOnlyStroke() {
        var rect = base("r", 10, 10, 100, 60)
        rect.backgroundColor = "transparent"
        let filled = geometry([ExcalidrawElement(base: { var b = rect; b.backgroundColor = "#a5d8ff"
            b.fillStyle = .solid; return b
        }(), kind: .rectangle)])
        let strokeOnly = geometry([ExcalidrawElement(base: rect, kind: .rectangle)])
        XCTAssertGreaterThan(filled.triangleCount, strokeOnly.triangleCount)
    }

    func testTransparentStrokeEmitsNothingForStrokeOnlyShape() {
        var rect = base("r", 10, 10, 100, 60)
        rect.strokeColor = "transparent"; rect.backgroundColor = "transparent"
        let g = geometry([ExcalidrawElement(base: rect, kind: .rectangle)])
        XCTAssertTrue(g.isEmpty)
        // Still recorded as handled so the CG overlay doesn't double-draw it.
        XCTAssertTrue(g.handledIDs.contains("r"))
    }

    func testArrowWithTriangleAndLineArrowheads() {
        let triangleHead = ArrowProperties(
            points: [Point(0, 0), Point(100, 0)], startArrowhead: .arrow, endArrowhead: .triangle
        )
        let g = geometry([ExcalidrawElement(base: base("a", 20, 20, 100, 0), kind: .arrow(triangleHead))])
        XCTAssertGreaterThan(g.triangleCount, 0)
        XCTAssertTrue(g.handledIDs.contains("a"))
    }

    func testRotationTransformMovesVertices() {
        var rect = base("r", 0, 0, 100, 100)
        let upright = geometry([ExcalidrawElement(base: rect, kind: .rectangle)])
        rect.angle = .pi / 4
        let rotated = geometry([ExcalidrawElement(base: rect, kind: .rectangle)])
        XCTAssertEqual(upright.vertices.count, rotated.vertices.count)
        XCTAssertNotEqual(upright.vertices, rotated.vertices, "rotation must change vertex positions")
    }

    func testElementTransformRotatesAboutCentre() {
        var b = base("r", 0, 0, 100, 100); b.angle = .pi / 2 // 90° about the centre (50,50)
        let transform = SceneGeometry.elementTransform(b)
        let mapped = transform(Point(0, 0)) // top-left → top-right after a 90° turn
        XCTAssertEqual(mapped.x, 100, accuracy: 1e-6)
        XCTAssertEqual(mapped.y, 0, accuracy: 1e-6)
    }

    func testOpacityScalesAlpha() {
        var rect = base("r", 0, 0, 100, 60); rect.backgroundColor = "#a5d8ff"; rect.fillStyle = .solid
        rect.opacity = 50
        let g = geometry([ExcalidrawElement(base: rect, kind: .rectangle)])
        // Alpha is the 6th float of each vertex; with 50% opacity it must be ~0.5.
        let alphas = stride(from: 5, to: g.vertices.count, by: 6).map { g.vertices[$0] }
        XCTAssertFalse(alphas.isEmpty)
        XCTAssertEqual(alphas.max() ?? 1, 0.5, accuracy: 0.02)
    }

    func testDarkThemeChangesColors() {
        var rect = base("r", 0, 0, 100, 60); rect.backgroundColor = "#a5d8ff"; rect.fillStyle = .solid
        let light = geometry([ExcalidrawElement(base: rect, kind: .rectangle)], theme: .light)
        let dark = geometry([ExcalidrawElement(base: rect, kind: .rectangle)], theme: .dark)
        XCTAssertNotEqual(light.vertices, dark.vertices)
    }

    func testLinePolygonIsTessellated() {
        let line = LinearProperties(points: [Point(0, 0), Point(100, 0), Point(100, 50)], polygon: true)
        let g = geometry([ExcalidrawElement(base: base("l", 0, 0, 100, 50), kind: .line(line))])
        XCTAssertGreaterThan(g.triangleCount, 0)
    }

    func testGeometryCacheReusesVerticesAndInvalidatesOnChange() {
        var rect = base("r", 10, 10, 100, 60); rect.backgroundColor = "#a5d8ff"; rect.fillStyle = .crossHatch
        let scene = Scene(elements: [ExcalidrawElement(base: rect, kind: .rectangle)])
        let cache = GeometryCache()

        let first = SceneGeometry(scene: scene, theme: .light, geometryCache: cache)
        XCTAssertEqual(cache.count, 1)
        let cached = SceneGeometry(scene: scene, theme: .light, geometryCache: cache)
        XCTAssertEqual(first.vertices, cached.vertices, "unchanged element must hit the cache identically")

        // A theme change must miss the cache and re-tessellate with new colors.
        let dark = SceneGeometry(scene: scene, theme: .dark, geometryCache: cache)
        XCTAssertEqual(first.vertices.count, dark.vertices.count)
        XCTAssertNotEqual(first.vertices, dark.vertices)

        // Moving the element invalidates its entry (geometry differs).
        var moved = rect; moved.x += 50
        let movedScene = Scene(elements: [ExcalidrawElement(base: moved, kind: .rectangle)])
        let movedGeo = SceneGeometry(scene: movedScene, theme: .light, geometryCache: cache)
        XCTAssertNotEqual(first.vertices, movedGeo.vertices)
    }

    /// Regression: emitting vertices must stay amortized O(1) per triangle. A
    /// tight `reserveCapacity` per emit previously made the build O(n²) — ~8 s
    /// for 200 shapes on an iPad. Build a large scene off a warm `ShapeCache`
    /// (so we time tessellation, not drawable generation) and assert it stays
    /// well under a generous bound that quadratic growth could never meet.
    func testLargeSceneGeometryBuildIsNotQuadratic() {
        let count = 800
        var elements: [ExcalidrawElement] = []
        let perRow = 30
        for i in 0 ..< count {
            var b = base("e\(i)", Double(i % perRow) * 90, Double(i / perRow) * 90, 70, 60)
            b.backgroundColor = "#a5d8ff"; b.fillStyle = .crossHatch; b.seed = i + 1
            elements.append(ExcalidrawElement(base: b, kind: i % 2 == 0 ? .rectangle : .ellipse))
        }
        let scene = Scene(elements: elements)
        let cache = ShapeCache()
        _ = SceneGeometry(scene: scene, theme: .light, shapeCache: cache) // warm drawables

        let start = Date()
        let g = SceneGeometry(scene: scene, theme: .light, shapeCache: cache)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertGreaterThan(g.triangleCount, 0)
        // Linear build is ~1 s for 800 shapes; the O(n²) regression was ~17 s.
        // A 6 s bound catches the regression with margin while tolerating slow CI.
        XCTAssertLessThan(elapsed, 6.0, "geometry build for \(count) shapes took \(elapsed)s — O(n²) regression")
    }
}
