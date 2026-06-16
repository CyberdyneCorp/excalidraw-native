import ExcalidrawMath
import XCTest
@testable import ExcalidrawGeometry

final class ElbowArrowTests: XCTestCase {
    private func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> BoundingBox {
        BoundingBox(minX: x, minY: y, maxX: x + w, maxY: y + h)
    }

    /// Every consecutive pair of points must form an axis-aligned segment.
    private func assertOrthogonal(_ points: [Point], file: StaticString = #filePath, line: UInt = #line) {
        for i in 0 ..< (points.count - 1) {
            let a = points[i], b = points[i + 1]
            let axisAligned = abs(a.x - b.x) < 1e-6 || abs(a.y - b.y) < 1e-6
            XCTAssertTrue(axisAligned, "segment \(i) (\(a)→\(b)) is not axis-aligned", file: file, line: line)
        }
    }

    func testFreeEndpointsProduceOrthogonalRoute() {
        let route = ElbowArrow.route(
            start: Point(0, 0), startBox: nil,
            end: Point(100, 60), endBox: nil
        )
        XCTAssertGreaterThanOrEqual(route.count, 2)
        XCTAssertEqual(route.first, Point(0, 0))
        XCTAssertEqual(route.last, Point(100, 60))
        assertOrthogonal(route)
    }

    func testColinearHorizontalEndpointsRouteStraight() {
        // Same y, free endpoints → a straight horizontal segment (no bends).
        let route = ElbowArrow.route(
            start: Point(0, 50), startBox: nil,
            end: Point(200, 50), endBox: nil
        )
        XCTAssertEqual(route.first, Point(0, 50))
        XCTAssertEqual(route.last, Point(200, 50))
        assertOrthogonal(route)
        for p in route {
            XCTAssertEqual(p.y, 50, accuracy: 1e-6)
        }
    }

    func testBoundBoxesRouteBetweenShapes() {
        // Two boxes separated horizontally; arrow leaves the right of A and
        // enters the left of B.
        let a = box(0, 0, 100, 100)
        let b = box(300, 0, 100, 100)
        let route = ElbowArrow.route(
            start: Point(100, 50), startBox: a,
            end: Point(300, 50), endBox: b
        )
        XCTAssertEqual(route.first, Point(100, 50))
        XCTAssertEqual(route.last, Point(300, 50))
        assertOrthogonal(route)
    }

    func testVerticallyStackedBoxesRoute() {
        let a = box(0, 0, 100, 100)
        let b = box(0, 300, 100, 100)
        let route = ElbowArrow.route(
            start: Point(50, 100), startBox: a,
            end: Point(50, 300), endBox: b
        )
        XCTAssertEqual(route.first, Point(50, 100))
        XCTAssertEqual(route.last, Point(50, 300))
        assertOrthogonal(route)
    }

    func testDiagonalBoxesProduceBend() {
        // Offset boxes force at least one corner.
        let a = box(0, 0, 80, 80)
        let b = box(260, 200, 80, 80)
        let route = ElbowArrow.route(
            start: Point(80, 40), startBox: a,
            end: Point(260, 240), endBox: b
        )
        assertOrthogonal(route)
        XCTAssertGreaterThanOrEqual(route.count, 3) // has at least one bend
    }
}
