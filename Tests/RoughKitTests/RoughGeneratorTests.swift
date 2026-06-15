import CoreGraphics
import ExcalidrawMath
import XCTest
@testable import RoughKit

final class RoughGeneratorTests: XCTestCase {
    private let gen = RoughGenerator()

    private func options(seed: Int = 1, _ configure: (inout RoughOptions) -> Void = { _ in }) -> RoughOptions {
        var o = RoughOptions()
        o.seed = seed
        configure(&o)
        return o
    }

    private func points(of drawable: Drawable) -> [Point] {
        drawable.sets.flatMap(\.ops).flatMap { op -> [Point] in
            switch op {
            case let .move(p), let .lineTo(p): return [p]
            case let .bcurveTo(c1, c2, e): return [c1, c2, e]
            }
        }
    }

    func testDeterministicForSameSeed() {
        let a = gen.rectangle(x: 0, y: 0, width: 100, height: 50, options: options(seed: 42))
        let b = gen.rectangle(x: 0, y: 0, width: 100, height: 50, options: options(seed: 42))
        XCTAssertEqual(a, b)
    }

    func testDifferentSeedsDiffer() {
        let a = gen.rectangle(x: 0, y: 0, width: 100, height: 50, options: options(seed: 1))
        let b = gen.rectangle(x: 0, y: 0, width: 100, height: 50, options: options(seed: 2))
        XCTAssertNotEqual(a, b)
    }

    func testRectangleOpCountDoubleStroke() {
        // 4 edges × 2 strokes × (move + bcurve) = 16 ops.
        let rect = gen.rectangle(x: 0, y: 0, width: 100, height: 50, options: options())
        XCTAssertEqual(rect.sets.count, 1)
        XCTAssertEqual(rect.sets[0].type, .path)
        XCTAssertEqual(rect.sets[0].ops.count, 16)
    }

    func testRectangleOpCountSingleStroke() {
        let rect = gen.rectangle(x: 0, y: 0, width: 100, height: 50, options: options { $0.disableMultiStroke = true })
        XCTAssertEqual(rect.sets[0].ops.count, 8)
    }

    func testLineOpCount() {
        let line = gen.line(Point(0, 0), Point(100, 0), options: options())
        XCTAssertEqual(line.sets[0].ops.count, 4) // 2 strokes × (move + bcurve)
    }

    func testPreserveVerticesKeepsFirstCornerExact() {
        let rect = gen.rectangle(
            x: 10, y: 20, width: 100, height: 40,
            options: options { $0.preserveVertices = true }
        )
        guard case let .move(first) = rect.sets[0].ops.first else { return XCTFail("expected move") }
        XCTAssertEqual(first, Point(10, 20))
    }

    func testGeneratedPointsStayNearIdealShape() {
        // With roughness 1 and maxRandomnessOffset 2, perturbations are small,
        // so the sketch stays close to the true rectangle.
        let rect = gen.rectangle(x: 0, y: 0, width: 100, height: 50, options: options())
        for p in points(of: rect) {
            XCTAssertGreaterThan(p.x, -8)
            XCTAssertLessThan(p.x, 108)
            XCTAssertGreaterThan(p.y, -8)
            XCTAssertLessThan(p.y, 58)
        }
    }

    func testPolygonAndLinearPathDifferByClosingEdge() {
        let pts = [Point(0, 0), Point(50, 0), Point(50, 50)]
        let open = gen.linearPath(pts, options: options())
        let closed = gen.polygon(pts, options: options())
        // The closed polygon has one extra edge (2 strokes × 2 ops = 4 more ops).
        XCTAssertEqual(closed.sets[0].ops.count, open.sets[0].ops.count + 4)
    }

    func testCGPathFromRectangleIsNonEmptyAndBounded() {
        let rect = gen.rectangle(x: 0, y: 0, width: 100, height: 50, options: options())
        let path = RoughPath.outlinePath(for: rect)
        XCTAssertFalse(path.isEmpty)
        let box = path.boundingBoxOfPath
        XCTAssertEqual(box.minX, 0, accuracy: 10)
        XCTAssertEqual(box.maxX, 100, accuracy: 10)
        XCTAssertEqual(box.minY, 0, accuracy: 10)
        XCTAssertEqual(box.maxY, 50, accuracy: 10)
    }

    func testLinearPathTwoPointsIsSingleDoubleLine() {
        // The 2-point branch returns one doubleLine: 2 strokes × (move + bcurve).
        let path = gen.linearPath([Point(0, 0), Point(100, 0)], options: options())
        XCTAssertEqual(path.sets[0].ops.count, 4)
    }

    func testCGPathHandlesEmptyAndLeadingLineTo() {
        XCTAssertTrue(RoughPath.cgPath(from: []).isEmpty)
        let path = RoughPath.cgPath(from: [.lineTo(Point(5, 5)), .lineTo(Point(10, 10))])
        XCTAssertFalse(path.isEmpty)
    }
}
