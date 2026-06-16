import ExcalidrawMath
import Foundation

/// Type-specific payload for an element. Generic shapes (rectangle/diamond/
/// ellipse), selection, embeddable and iframe carry no extra typed fields
/// (iframe's generation data lives in `customData`).
public enum ElementKind: Equatable, Sendable {
    case selection
    case rectangle
    case diamond
    case ellipse
    case embeddable
    case iframe
    case text(TextProperties)
    case freedraw(FreedrawProperties)
    case line(LinearProperties)
    case arrow(ArrowProperties)
    case image(ImageProperties)
    case frame(name: String?)
    case magicframe(name: String?)

    /// The `type` discriminator as written to JSON.
    public var typeName: String {
        switch self {
        case .selection: "selection"
        case .rectangle: "rectangle"
        case .diamond: "diamond"
        case .ellipse: "ellipse"
        case .embeddable: "embeddable"
        case .iframe: "iframe"
        case .text: "text"
        case .freedraw: "freedraw"
        case .line: "line"
        case .arrow: "arrow"
        case .image: "image"
        case .frame: "frame"
        case .magicframe: "magicframe"
        }
    }
}

public struct TextProperties: Equatable, Sendable {
    public var fontSize: Double
    public var fontFamily: Int
    public var text: String
    public var textAlign: TextAlign
    public var verticalAlign: VerticalAlign
    public var containerId: String?
    public var originalText: String
    public var autoResize: Bool
    public var lineHeight: Double

    public init(
        fontSize: Double = 20,
        fontFamily: Int = FontFamily.default,
        text: String = "",
        textAlign: TextAlign = .left,
        verticalAlign: VerticalAlign = .top,
        containerId: String? = nil,
        originalText: String = "",
        autoResize: Bool = true,
        lineHeight: Double = 1.25
    ) {
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.text = text
        self.textAlign = textAlign
        self.verticalAlign = verticalAlign
        self.containerId = containerId
        self.originalText = originalText
        self.autoResize = autoResize
        self.lineHeight = lineHeight
    }
}

public struct FreedrawProperties: Equatable, Sendable {
    public var points: [Point]
    public var pressures: [Double]
    public var simulatePressure: Bool

    public init(points: [Point] = [], pressures: [Double] = [], simulatePressure: Bool = true) {
        self.points = points
        self.pressures = pressures
        self.simulatePressure = simulatePressure
    }
}

public struct LinearProperties: Equatable, Sendable {
    public var points: [Point]
    public var startBinding: FixedPointBinding?
    public var endBinding: FixedPointBinding?
    public var startArrowhead: Arrowhead?
    public var endArrowhead: Arrowhead?
    public var polygon: Bool

    public init(
        points: [Point] = [],
        startBinding: FixedPointBinding? = nil,
        endBinding: FixedPointBinding? = nil,
        startArrowhead: Arrowhead? = nil,
        endArrowhead: Arrowhead? = nil,
        polygon: Bool = false
    ) {
        self.points = points
        self.startBinding = startBinding
        self.endBinding = endBinding
        self.startArrowhead = startArrowhead
        self.endArrowhead = endArrowhead
        self.polygon = polygon
    }
}

public struct ArrowProperties: Equatable, Sendable {
    public var points: [Point]
    public var startBinding: FixedPointBinding?
    public var endBinding: FixedPointBinding?
    public var startArrowhead: Arrowhead?
    public var endArrowhead: Arrowhead?
    public var elbowed: Bool
    public var fixedSegments: [FixedSegment]?
    public var startIsSpecial: Bool?
    public var endIsSpecial: Bool?

    public init(
        points: [Point] = [],
        startBinding: FixedPointBinding? = nil,
        endBinding: FixedPointBinding? = nil,
        startArrowhead: Arrowhead? = nil,
        endArrowhead: Arrowhead? = nil,
        elbowed: Bool = false,
        fixedSegments: [FixedSegment]? = nil,
        startIsSpecial: Bool? = nil,
        endIsSpecial: Bool? = nil
    ) {
        self.points = points
        self.startBinding = startBinding
        self.endBinding = endBinding
        self.startArrowhead = startArrowhead
        self.endArrowhead = endArrowhead
        self.elbowed = elbowed
        self.fixedSegments = fixedSegments
        self.startIsSpecial = startIsSpecial
        self.endIsSpecial = endIsSpecial
    }
}

public struct ImageProperties: Equatable, Sendable {
    public var fileId: String?
    public var status: ImageStatus
    public var scale: Point
    public var crop: ImageCrop?

    public init(
        fileId: String? = nil,
        status: ImageStatus = .pending,
        scale: Point = Point(1, 1),
        crop: ImageCrop? = nil
    ) {
        self.fileId = fileId
        self.status = status
        self.scale = scale
        self.crop = crop
    }
}
