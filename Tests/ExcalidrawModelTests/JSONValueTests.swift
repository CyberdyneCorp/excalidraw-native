import XCTest
@testable import ExcalidrawModel

final class JSONValueTests: XCTestCase {
    private func roundTrip(_ value: JSONValue) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    func testAllCasesRoundTrip() throws {
        let nested: JSONValue = .object([
            "n": .null,
            "b": .bool(false),
            "num": .number(3.5),
            "s": .string("hi"),
            "arr": .array([.number(1), .string("two"), .bool(true), .null]),
            "obj": .object(["k": .string("v")])
        ])
        XCTAssertEqual(try roundTrip(nested), nested)
    }

    func testNullRoundTrips() throws {
        XCTAssertEqual(try roundTrip(.null), .null)
    }

    func testTopLevelScalars() throws {
        XCTAssertEqual(try roundTrip(.string("x")), .string("x"))
        XCTAssertEqual(try roundTrip(.bool(true)), .bool(true))
        XCTAssertEqual(try roundTrip(.number(-2.25)), .number(-2.25))
    }
}
