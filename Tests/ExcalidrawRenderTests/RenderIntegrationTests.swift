import CoreGraphics
import ExcalidrawMath
import ExcalidrawModel
import RoughKit
import XCTest
@testable import ExcalidrawRender

final class RenderIntegrationTests: XCTestCase {
    private func element(
        _ kind: ElementKind, x: Double = 0, y: Double = 0, w: Double = 100, h: Double = 60,
        seed: Int = 1, stroke: StrokeStyle = .solid, bg: String = "transparent", roughness: Double = 1
    ) -> ExcalidrawElement {
        var base = BaseProperties(id: "e")
        base.x = x; base.y = y; base.width = w; base.height = h
        base.seed = seed; base.strokeStyle = stroke; base.backgroundColor = bg; base.roughness = roughness
        return ExcalidrawElement(base: base, kind: kind)
    }

    // MARK: Options

    func testDashedStrokeProducesDashArray() {
        let o = RoughOptionsBuilder.options(for: element(.rectangle, stroke: .dashed))
        XCTAssertEqual(o.strokeLineDash, [8, 10]) // [8, 8 + strokeWidth(2)]
        XCTAssertTrue(o.disableMultiStroke)
    }

    func testFillFromBackground() {
        let opaque = RoughOptionsBuilder.options(for: element(.rectangle, bg: "#a5d8ff"))
        XCTAssertEqual(opaque.fill, "#a5d8ff")
        let transparent = RoughOptionsBuilder.options(for: element(.rectangle, bg: "transparent"))
        XCTAssertNil(transparent.fill)
    }

    func testDefaultRoughnessPreservesVertices() {
        XCTAssertTrue(RoughOptionsBuilder.options(for: element(.rectangle, roughness: 1)).preserveVertices)
        XCTAssertFalse(RoughOptionsBuilder.options(for: element(.rectangle, roughness: 2)).preserveVertices)
    }

    func testSmallShapeRoughnessReduced() {
        let small = element(.rectangle, w: 8, h: 8, roughness: 2)
        XCTAssertLessThanOrEqual(RoughOptionsBuilder.adjustRoughness(small), 2.5)
        XCTAssertEqual(RoughOptionsBuilder.adjustRoughness(small), 1) // 2/2
    }

    // MARK: Drawables

    func testRectangleAndDiamondDrawables() {
        XCTAssertNotNil(ElementDrawable.drawable(for: element(.rectangle)))
        let diamond = ElementDrawable.drawable(for: element(.diamond))
        XCTAssertEqual(diamond?.shape, "polygon")
    }

    func testLineVsPolygon() {
        let openLine = LinearProperties(points: [Point(0, 0), Point(50, 0), Point(50, 50)])
        XCTAssertEqual(ElementDrawable.drawable(for: element(.line(openLine)))?.shape, "linearPath")
        let closedLine = LinearProperties(points: [Point(0, 0), Point(50, 0), Point(50, 50)], polygon: true)
        XCTAssertEqual(ElementDrawable.drawable(for: element(.line(closedLine)))?.shape, "polygon")
    }

    func testEllipseDrawableIsGenerated() {
        XCTAssertEqual(ElementDrawable.drawable(for: element(.ellipse))?.shape, "ellipse")
    }

    func testRendererHandledKindsReturnNilDrawable() {
        // Text, image, freedraw and frame are drawn directly by the renderer.
        XCTAssertNil(ElementDrawable.drawable(for: element(.text(TextProperties()))))
        XCTAssertNil(ElementDrawable.drawable(for: element(.freedraw(FreedrawProperties()))))
        XCTAssertNil(ElementDrawable.drawable(for: element(.image(ImageProperties()))))
    }

    func testArrowDrawableIsLinearPath() {
        let arrow = ArrowProperties(points: [Point(0, 0), Point(80, 20)])
        XCTAssertEqual(ElementDrawable.drawable(for: element(.arrow(arrow)))?.shape, "linearPath")
    }

    func testEllipseOptionsSetCurveFittingAndFill() {
        let o = RoughOptionsBuilder.options(for: element(.ellipse, bg: "#ffd43b"))
        XCTAssertEqual(o.curveFitting, 1)
        XCTAssertEqual(o.fill, "#ffd43b")
    }

    func testClosedLineAndFreedrawGetFill() {
        let loopPts = [Point(0, 0), Point(50, 0), Point(50, 50), Point(0, 0)]
        let line = RoughOptionsBuilder.options(for: element(.line(LinearProperties(points: loopPts)), bg: "#b2f2bb"))
        XCTAssertEqual(line.fill, "#b2f2bb")
        let freeEl = element(.freedraw(FreedrawProperties(points: loopPts)), bg: "#b2f2bb")
        XCTAssertEqual(RoughOptionsBuilder.options(for: freeEl).fill, "#b2f2bb")
    }

    func testPolygonFlaggedLineGetsFillWithoutClosingPoint() {
        // A polygon-flagged line whose endpoints don't coincide should still fill.
        let openPts = [Point(0, 0), Point(50, 0), Point(25, 40)]
        let props = LinearProperties(points: openPts, polygon: true)
        let line = RoughOptionsBuilder.options(for: element(.line(props), bg: "#ffc9c9"))
        XCTAssertEqual(line.fill, "#ffc9c9")
        // A non-polygon open line stays unfilled.
        let openLine = RoughOptionsBuilder.options(for: element(
            .line(LinearProperties(points: openPts)),
            bg: "#ffc9c9"
        ))
        XCTAssertNil(openLine.fill)
    }

    func testFillStyleCarriesIntoOptions() {
        let loopPts = [Point(0, 0), Point(50, 0), Point(50, 50), Point(0, 0)]
        var el = element(.line(LinearProperties(points: loopPts)), bg: "#b2f2bb")
        el.base.fillStyle = .crossHatch
        XCTAssertEqual(RoughOptionsBuilder.options(for: el).fillStyle, "cross-hatch")
    }

    func testShapeCacheRemoveAll() {
        let cache = ShapeCache()
        _ = cache.drawable(for: element(.rectangle))
        XCTAssertEqual(cache.count, 1)
        cache.removeAll()
        XCTAssertEqual(cache.count, 0)
    }

    // MARK: ShapeCache

    func testShapeCacheMemoizesAndInvalidates() {
        let cache = ShapeCache()
        var rect = element(.rectangle)
        _ = cache.drawable(for: rect)
        XCTAssertEqual(cache.count, 1)
        _ = cache.drawable(for: rect) // cache hit, no new entry
        XCTAssertEqual(cache.count, 1)

        rect.base.version = 2 // version change forces regeneration
        let regenerated = cache.drawable(for: rect)
        XCTAssertNotNil(regenerated)

        cache.invalidate(id: rect.id)
        XCTAssertEqual(cache.count, 0)
    }

    func testShapeCacheRegeneratesOnGeometryChangeWithoutVersionBump() {
        // Regression: while drawing/resizing, size changes via Scene.replace
        // WITHOUT a version bump. The cache must still regenerate (otherwise the
        // shape renders at its initial 0×0 size — an empty box).
        let cache = ShapeCache()
        var rect = element(.rectangle, w: 0, h: 0)
        let zeroSize = cache.drawable(for: rect)
        rect.base.width = 120
        rect.base.height = 80 // no version change, as during a live drag
        let resized = cache.drawable(for: rect)
        XCTAssertNotEqual(zeroSize, resized)
    }

    // MARK: First pixels

    func testRectangleRastersToNonBlankImage() throws {
        let rect = element(.rectangle, x: 10, y: 10, w: 100, h: 60)
        let drawable = try XCTUnwrap(ElementDrawable.drawable(for: rect))

        let width = 130, height = 90
        let ctx = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        ctx.saveGState()
        ctx.translateBy(x: rect.base.x, y: rect.base.y)
        ctx.addPath(RoughPath.outlinePath(for: drawable))
        ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.setLineWidth(2)
        ctx.strokePath()
        ctx.restoreGState()

        let data = try XCTUnwrap(ctx.data)
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var inkedPixels = 0
        for i in stride(from: 0, to: width * height * 4, by: 4) where pixels[i] < 128 {
            inkedPixels += 1 // a dark (inked) pixel
        }
        XCTAssertGreaterThan(inkedPixels, 50, "expected the rectangle stroke to ink pixels")
    }
}
