import ExcalidrawMath
import Foundation

/// Corner rounding descriptor (`roundness: { type, value? } | null`).
public struct Roundness: Codable, Equatable, Sendable {
    public var type: Int
    public var value: Double?

    public init(type: Int, value: Double? = nil) {
        self.type = type
        self.value = value
    }
}

/// Reference to an element bound to this one (`BoundElement`).
public struct BoundElement: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case arrow, text }
    public var id: String
    public var type: Kind

    public init(id: String, type: Kind) {
        self.id = id
        self.type = type
    }
}

/// Arrow-to-shape binding in the current (`fixedPoint` + `mode`) form
/// (`FixedPointBinding`). Legacy `focus`/`gap` bindings are migrated on load by
/// the restore step (Phase 1, incremental).
public struct FixedPointBinding: Codable, Equatable, Sendable {
    public var elementId: String
    public var fixedPoint: Point
    public var mode: BindMode

    public init(elementId: String, fixedPoint: Point, mode: BindMode) {
        self.elementId = elementId
        self.fixedPoint = fixedPoint
        self.mode = mode
    }
}

/// A user-pinned segment of an elbow arrow (`FixedSegment`).
public struct FixedSegment: Codable, Equatable, Sendable {
    public var start: Point
    public var end: Point
    public var index: Int

    public init(start: Point, end: Point, index: Int) {
        self.start = start
        self.end = end
        self.index = index
    }
}

/// Image crop rectangle in natural-image coordinates (`ImageCrop`).
public struct ImageCrop: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var naturalWidth: Double
    public var naturalHeight: Double

    public init(
        x: Double, y: Double, width: Double, height: Double,
        naturalWidth: Double, naturalHeight: Double
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.naturalWidth = naturalWidth
        self.naturalHeight = naturalHeight
    }
}

/// Arbitrary JSON value, used for `customData` and unmodelled extras so they
/// round-trip losslessly.
public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = try .object(container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }
}
