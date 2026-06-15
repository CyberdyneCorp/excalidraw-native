import ExcalidrawMath
import ExcalidrawModel
import Foundation
import RoughKit

/// Builds rough.js options for an element, porting `generateRoughOptions`
/// (`packages/element/src/shape.ts`).
public enum RoughOptionsBuilder {
    enum Roughness {
        static let cartoonist = 2.0
    }

    public static func options(for element: ExcalidrawElement, continuousPath: Bool = false) -> RoughOptions {
        let base = element.base
        var o = RoughOptions()
        o.seed = base.seed

        let solid = base.strokeStyle == .solid
        o.disableMultiStroke = !solid
        o.strokeWidth = solid ? base.strokeWidth : base.strokeWidth + 0.5
        o.fillWeight = base.strokeWidth / 2
        o.hachureGap = base.strokeWidth * 4
        o.roughness = adjustRoughness(element)
        // Default "artist" roughness (1) renders with preserved vertices.
        o.preserveVertices = continuousPath || base.roughness < Roughness.cartoonist

        switch base.strokeStyle {
        case .dashed: o.strokeLineDash = [8, 8 + base.strokeWidth]
        case .dotted: o.strokeLineDash = [1.5, 6 + base.strokeWidth]
        case .solid: o.strokeLineDash = nil
        }

        switch element.kind {
        case .rectangle, .iframe, .embeddable, .diamond, .ellipse:
            o.fillStyle = base.fillStyle.rawValue
            o.fill = isTransparent(base.backgroundColor) ? nil : base.backgroundColor
            if case .ellipse = element.kind { o.curveFitting = 1 }
        case let .line(props):
            if isPathALoop(props.points) {
                o.fillStyle = base.fillStyle.rawValue
                o.fill = isTransparent(base.backgroundColor) ? nil : base.backgroundColor
            }
        case let .freedraw(props):
            if isPathALoop(props.points) {
                o.fillStyle = base.fillStyle.rawValue
                o.fill = isTransparent(base.backgroundColor) ? nil : base.backgroundColor
            }
        default:
            break
        }
        return o
    }

    /// Reduce roughness for small shapes so the sketch doesn't look noisy
    /// (`adjustRoughness`). NOTE: approximate thresholds; exact tuning is a
    /// later refinement.
    static func adjustRoughness(_ element: ExcalidrawElement) -> Double {
        let roughness = element.base.roughness
        let maxSize = Swift.max(element.base.width, element.base.height)
        let minSize = Swift.min(element.base.width, element.base.height)
        if minSize >= 20, maxSize >= 50 { return roughness }
        return Swift.min(roughness / 2, 2.5)
    }

    static func isPathALoop(_ points: [Point]) -> Bool {
        guard points.count >= 3, let first = points.first, let last = points.last else { return false }
        return first.distance(to: last) <= 40 // LINE_CONFIRM_THRESHOLD
    }

    static func isTransparent(_ color: String) -> Bool {
        if color == "transparent" || color.isEmpty { return true }
        return color.count == 9 && color.hasPrefix("#") && color.hasSuffix("00")
    }
}
