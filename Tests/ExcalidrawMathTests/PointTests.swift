import XCTest
@testable import ExcalidrawMath

final class PointTests: XCTestCase {
    func testDistance() {
        let a = Point(0, 0)
        let b = Point(3, 4)
        XCTAssertEqual(a.distance(to: b), 5, accuracy: ExcalidrawMath.precision)
    }

    func testArithmetic() {
        let sum = Point(1, 2) + Point(3, 4)
        XCTAssertEqual(sum, Point(4, 6))
        let diff = Point(5, 5) - Point(2, 1)
        XCTAssertEqual(diff, Point(3, 4))
    }

    func testMagnitude() {
        XCTAssertEqual(Point(3, 4).magnitude, 5, accuracy: ExcalidrawMath.precision)
    }

    func testEncodesAsJSONArray() throws {
        let data = try JSONEncoder().encode(Point(1.5, -2))
        XCTAssertEqual(String(bytes: data, encoding: .utf8), "[1.5,-2]")
    }

    func testDecodesFromJSONArray() throws {
        let point = try JSONDecoder().decode(Point.self, from: Data("[3,4]".utf8))
        XCTAssertEqual(point, Point(3, 4))
    }
}
