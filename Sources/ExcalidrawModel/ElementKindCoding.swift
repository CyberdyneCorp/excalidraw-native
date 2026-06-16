import ExcalidrawMath
import Foundation

/// Coding for the type-specific payloads, all reading/writing through the shared
/// flat container so they sit alongside the base fields in JSON.
extension TextProperties {
    init(from c: KeyedDecodingContainer<ElementCodingKeys>) throws {
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 20
        fontFamily = try c.decodeIfPresent(Int.self, forKey: .fontFamily) ?? FontFamily.default
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        textAlign = try c.decodeIfPresent(TextAlign.self, forKey: .textAlign) ?? .left
        verticalAlign = try c.decodeIfPresent(VerticalAlign.self, forKey: .verticalAlign) ?? .top
        containerId = try c.decodeIfPresent(String.self, forKey: .containerId)
        originalText = try c.decodeIfPresent(String.self, forKey: .originalText) ?? text
        autoResize = try c.decodeIfPresent(Bool.self, forKey: .autoResize) ?? true
        lineHeight = try c.decodeIfPresent(Double.self, forKey: .lineHeight) ?? 1.25
    }

    func encode(into c: inout KeyedEncodingContainer<ElementCodingKeys>) throws {
        try c.encode(fontSize, forKey: .fontSize)
        try c.encode(fontFamily, forKey: .fontFamily)
        try c.encode(text, forKey: .text)
        try c.encode(textAlign, forKey: .textAlign)
        try c.encode(verticalAlign, forKey: .verticalAlign)
        try c.encode(containerId, forKey: .containerId)
        try c.encode(originalText, forKey: .originalText)
        try c.encode(autoResize, forKey: .autoResize)
        try c.encode(lineHeight, forKey: .lineHeight)
    }
}

extension FreedrawProperties {
    init(from c: KeyedDecodingContainer<ElementCodingKeys>) throws {
        points = try c.decodeIfPresent([Point].self, forKey: .points) ?? []
        pressures = try c.decodeIfPresent([Double].self, forKey: .pressures) ?? []
        simulatePressure = try c.decodeIfPresent(Bool.self, forKey: .simulatePressure) ?? true
    }

    func encode(into c: inout KeyedEncodingContainer<ElementCodingKeys>) throws {
        try c.encode(points, forKey: .points)
        try c.encode(pressures, forKey: .pressures)
        try c.encode(simulatePressure, forKey: .simulatePressure)
    }
}

extension LinearProperties {
    init(from c: KeyedDecodingContainer<ElementCodingKeys>) throws {
        points = try c.decodeIfPresent([Point].self, forKey: .points) ?? []
        startBinding = try c.decodeIfPresent(FixedPointBinding.self, forKey: .startBinding)
        endBinding = try c.decodeIfPresent(FixedPointBinding.self, forKey: .endBinding)
        startArrowhead = try c.decodeIfPresent(Arrowhead.self, forKey: .startArrowhead)
        endArrowhead = try c.decodeIfPresent(Arrowhead.self, forKey: .endArrowhead)
        polygon = try c.decodeIfPresent(Bool.self, forKey: .polygon) ?? false
    }

    func encode(into c: inout KeyedEncodingContainer<ElementCodingKeys>) throws {
        try c.encode(points, forKey: .points)
        try c.encode(startBinding, forKey: .startBinding)
        try c.encode(endBinding, forKey: .endBinding)
        try c.encode(startArrowhead, forKey: .startArrowhead)
        try c.encode(endArrowhead, forKey: .endArrowhead)
        try c.encode(polygon, forKey: .polygon)
    }
}

extension ArrowProperties {
    init(from c: KeyedDecodingContainer<ElementCodingKeys>) throws {
        points = try c.decodeIfPresent([Point].self, forKey: .points) ?? []
        startBinding = try c.decodeIfPresent(FixedPointBinding.self, forKey: .startBinding)
        endBinding = try c.decodeIfPresent(FixedPointBinding.self, forKey: .endBinding)
        startArrowhead = try c.decodeIfPresent(Arrowhead.self, forKey: .startArrowhead)
        endArrowhead = try c.decodeIfPresent(Arrowhead.self, forKey: .endArrowhead)
        elbowed = try c.decodeIfPresent(Bool.self, forKey: .elbowed) ?? false
        fixedSegments = try c.decodeIfPresent([FixedSegment].self, forKey: .fixedSegments)
        startIsSpecial = try c.decodeIfPresent(Bool.self, forKey: .startIsSpecial)
        endIsSpecial = try c.decodeIfPresent(Bool.self, forKey: .endIsSpecial)
    }

    func encode(into c: inout KeyedEncodingContainer<ElementCodingKeys>) throws {
        try c.encode(points, forKey: .points)
        try c.encode(startBinding, forKey: .startBinding)
        try c.encode(endBinding, forKey: .endBinding)
        try c.encode(startArrowhead, forKey: .startArrowhead)
        try c.encode(endArrowhead, forKey: .endArrowhead)
        try c.encode(elbowed, forKey: .elbowed)
        if elbowed {
            try c.encodeIfPresent(fixedSegments, forKey: .fixedSegments)
            try c.encodeIfPresent(startIsSpecial, forKey: .startIsSpecial)
            try c.encodeIfPresent(endIsSpecial, forKey: .endIsSpecial)
        }
    }
}

extension ImageProperties {
    init(from c: KeyedDecodingContainer<ElementCodingKeys>) throws {
        fileId = try c.decodeIfPresent(String.self, forKey: .fileId)
        status = try c.decodeIfPresent(ImageStatus.self, forKey: .status) ?? .pending
        scale = try c.decodeIfPresent(Point.self, forKey: .scale) ?? Point(1, 1)
        crop = try c.decodeIfPresent(ImageCrop.self, forKey: .crop)
    }

    func encode(into c: inout KeyedEncodingContainer<ElementCodingKeys>) throws {
        try c.encode(fileId, forKey: .fileId)
        try c.encode(status, forKey: .status)
        try c.encode(scale, forKey: .scale)
        try c.encode(crop, forKey: .crop)
    }
}

extension ElementKind {
    init(type: String, from c: KeyedDecodingContainer<ElementCodingKeys>) throws {
        switch type {
        case "selection": self = .selection
        case "rectangle": self = .rectangle
        case "diamond": self = .diamond
        case "ellipse": self = .ellipse
        case "embeddable": self = .embeddable
        case "iframe": self = .iframe
        case "text": self = try .text(TextProperties(from: c))
        case "freedraw": self = try .freedraw(FreedrawProperties(from: c))
        case "line": self = try .line(LinearProperties(from: c))
        case "arrow": self = try .arrow(ArrowProperties(from: c))
        case "image": self = try .image(ImageProperties(from: c))
        case "frame": self = try .frame(name: c.decodeIfPresent(String.self, forKey: .name))
        case "magicframe": self = try .magicframe(name: c.decodeIfPresent(String.self, forKey: .name))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c, debugDescription: "Unknown element type \"\(type)\""
            )
        }
    }

    func encode(into c: inout KeyedEncodingContainer<ElementCodingKeys>) throws {
        switch self {
        case let .text(props): try props.encode(into: &c)
        case let .freedraw(props): try props.encode(into: &c)
        case let .line(props): try props.encode(into: &c)
        case let .arrow(props): try props.encode(into: &c)
        case let .image(props): try props.encode(into: &c)
        case let .frame(name): try c.encode(name, forKey: .name)
        case let .magicframe(name): try c.encode(name, forKey: .name)
        case .selection, .rectangle, .diamond, .ellipse, .embeddable, .iframe:
            break // no type-specific fields
        }
    }
}
