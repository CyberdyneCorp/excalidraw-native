import ExcalidrawMath
import RoughKit
import XCTest
@testable import ExcalidrawMetal

final class TessellatorTests: XCTestCase {
    func testFlattenSplitsSubpathsOnMove() {
        let ops: [PathOp] = [
            .move(Point(0, 0)), .lineTo(Point(10, 0)),
            .move(Point(0, 10)), .lineTo(Point(10, 10))
        ]
        let subs = Tessellator.flatten(ops)
        XCTAssertEqual(subs.count, 2)
        XCTAssertEqual(subs[0].count, 2)
        XCTAssertEqual(subs[1].count, 2)
    }

    func testFlattenSubdividesCurve() {
        let ops: [PathOp] = [
            .move(Point(0, 0)),
            .bcurveTo(Point(0, 10), Point(10, 10), Point(10, 0))
        ]
        let subs = Tessellator.flatten(ops, curveSegments: 8)
        XCTAssertEqual(subs.count, 1)
        // Start point + 8 sampled points.
        XCTAssertEqual(subs[0].count, 9)
        XCTAssertEqual(subs[0].last, Point(10, 0))
    }

    func testStrokeTrianglesProduceMultipleOfThree() {
        let tris = Tessellator.strokeTriangles([Point(0, 0), Point(10, 0)], halfWidth: 1)
        XCTAssertFalse(tris.isEmpty)
        XCTAssertEqual(tris.count % 3, 0)
    }

    func testStrokeWidthIsRespected() {
        // A horizontal segment of half-width 5 must span y in [-5, 5].
        let tris = Tessellator.strokeTriangles([Point(0, 0), Point(10, 0)], halfWidth: 5, capSegments: 4)
        let maxY = tris.map(\.y).max() ?? 0
        let minY = tris.map(\.y).min() ?? 0
        XCTAssertEqual(maxY, 5, accuracy: 1e-6)
        XCTAssertEqual(minY, -5, accuracy: 1e-6)
    }

    func testFillTrianglesOfSquare() {
        let square = [Point(0, 0), Point(10, 0), Point(10, 10), Point(0, 10)]
        let tris = Tessellator.fillTriangles(square)
        // Two triangles cover a quad.
        XCTAssertEqual(tris.count, 6)
        XCTAssertEqual(triangleArea(tris), 100, accuracy: 1e-6)
    }

    func testFillTrianglesOfConcavePolygon() {
        // An arrow/notch (concave) — ear clipping must still cover its area.
        let poly = [
            Point(0, 0), Point(10, 0), Point(10, 10),
            Point(5, 5), Point(0, 10)
        ]
        let tris = Tessellator.fillTriangles(poly)
        XCTAssertEqual(tris.count % 3, 0)
        XCTAssertEqual(triangleArea(tris), 75, accuracy: 1e-6)
    }

    func testDegeneratePolygonYieldsNoTriangles() {
        XCTAssertTrue(Tessellator.fillTriangles([Point(0, 0), Point(1, 1)]).isEmpty)
    }

    private func triangleArea(_ tris: [Point]) -> Double {
        var area = 0.0
        for i in stride(from: 0, to: tris.count, by: 3) {
            let a = tris[i], b = tris[i + 1], c = tris[i + 2]
            area += abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2
        }
        return area
    }
}
