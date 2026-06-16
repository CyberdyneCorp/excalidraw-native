import Foundation
import XCTest

/// Compares two JSON payloads for semantic equality, ignoring key order,
/// whitespace, number formatting (100 vs 100.0), and the difference between an
/// absent key and an explicit `null`. This is the right notion of "diff-clean"
/// for round-trip tests: structure and values must match, presentation need not.
enum JSONNormalized: Equatable {
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONNormalized])
    case object([String: JSONNormalized])

    init?(_ value: Any) {
        switch value {
        case is NSNull:
            return nil // nulls are dropped
        case let number as NSNumber:
            // Distinguish JSON booleans from numbers.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.doubleValue)
            }
        case let string as String:
            self = .string(string)
        case let array as [Any]:
            self = .array(array.compactMap(JSONNormalized.init))
        case let dict as [String: Any]:
            var object: [String: JSONNormalized] = [:]
            for (key, value) in dict {
                if let normalized = JSONNormalized(value) { object[key] = normalized }
            }
            self = .object(object)
        default:
            return nil
        }
    }
}

func assertJSONSemanticallyEqual(
    _ lhs: Data, _ rhs: Data, file: StaticString = #filePath, line: UInt = #line
) {
    do {
        let a = try JSONNormalized(JSONSerialization.jsonObject(with: lhs, options: [.fragmentsAllowed]))
        let b = try JSONNormalized(JSONSerialization.jsonObject(with: rhs, options: [.fragmentsAllowed]))
        XCTAssertEqual(a, b, "JSON payloads differ semantically", file: file, line: line)
    } catch {
        XCTFail("Failed to parse JSON: \(error)", file: file, line: line)
    }
}

/// Locates the repository `Fixtures/` directory relative to this source file so
/// tests can read sample documents without resource bundling.
enum Fixtures {
    static func data(_ name: String, file _: StaticString = #filePath) throws -> Data {
        // <root>/Tests/ExcalidrawModelTests/<thisFile> -> up 3 to <root>.
        let thisFile = URL(fileURLWithPath: "\(#filePath)")
        let root = thisFile.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("Fixtures").appendingPathComponent(name)
        return try Data(contentsOf: url)
    }
}
