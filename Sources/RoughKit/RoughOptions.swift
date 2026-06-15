import Foundation

/// Options controlling rough.js shape generation (`ResolvedOptions`). Defaults
/// match rough.js; Excalidraw overrides a subset per element in
/// `generateRoughOptions` (`packages/element/src/shape.ts`).
public struct RoughOptions: Equatable, Sendable {
    public var maxRandomnessOffset: Double = 2
    public var roughness: Double = 1
    public var bowing: Double = 1
    public var strokeWidth: Double = 1
    public var curveFitting: Double = 0.95
    public var curveTightness: Double = 0
    public var curveStepCount: Double = 9
    public var fillStyle: String = "hachure"
    public var fillWeight: Double = -1
    public var hachureAngle: Double = -41
    public var hachureGap: Double = -1
    public var dashOffset: Double = -1
    public var dashGap: Double = -1
    public var zigzagOffset: Double = -1
    public var seed: Int = 0
    public var strokeLineDash: [Double]?
    public var disableMultiStroke: Bool = false
    public var disableMultiStrokeFill: Bool = false
    public var preserveVertices: Bool = false
    /// Fill colour; `nil` means no fill (stroke only).
    public var fill: String?

    public init() {}
}
