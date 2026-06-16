import ExcalidrawMath
import Foundation

/// A single Excalidraw element: shared `base` properties plus a type-specific
/// `kind` payload. Encodes/decodes to the flat `.excalidraw` object shape where
/// base and type fields live side by side under a `type` discriminator.
public struct ExcalidrawElement: Equatable, Sendable, Identifiable, Codable {
    public var base: BaseProperties
    public var kind: ElementKind

    public var id: String {
        base.id
    }

    public var type: String {
        kind.typeName
    }

    public init(base: BaseProperties, kind: ElementKind) {
        self.base = base
        self.kind = kind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ElementCodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        base = try BaseProperties(from: container)
        kind = try ElementKind(type: type, from: container)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ElementCodingKeys.self)
        try container.encode(kind.typeName, forKey: .type)
        try base.encode(into: &container)
        try kind.encode(into: &container)
    }
}
