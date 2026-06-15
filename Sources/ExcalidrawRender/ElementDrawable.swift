import ExcalidrawMath
import ExcalidrawModel
import Foundation
import RoughKit

/// Generates the rough.js `Drawable` for an element, in element-local
/// coordinates (origin at the element's `x, y`). The scene renderer applies the
/// element's translation and rotation when drawing. Ports the dispatch in
/// `_generateElementShape` (`packages/element/src/shape.ts`).
///
/// Scope: rectangle, diamond, line, arrow this increment. Ellipse, freedraw and
/// text shapes are the next Phase 2 increment.
public enum ElementDrawable {
    private static let generator = RoughGenerator()

    public static func drawable(for element: ExcalidrawElement) -> Drawable? {
        let o = RoughOptionsBuilder.options(for: element)
        let w = element.base.width
        let h = element.base.height

        switch element.kind {
        case .rectangle, .embeddable, .iframe:
            return generator.rectangle(x: 0, y: 0, width: w, height: h, options: o)
        case .diamond:
            // Diamond vertices at the midpoints of each bounding-box edge.
            let pts = [Point(w / 2, 0), Point(w, h / 2), Point(w / 2, h), Point(0, h / 2)]
            return generator.polygon(pts, options: o)
        case let .line(props):
            return props.polygon || isLoop(props.points)
                ? generator.polygon(props.points, options: o)
                : generator.linearPath(props.points, options: o)
        case let .arrow(props):
            return generator.linearPath(props.points, options: o)
        default:
            return nil // ellipse / freedraw / text / image / frame: later increments
        }
    }

    private static func isLoop(_ points: [Point]) -> Bool {
        guard points.count >= 3, let first = points.first, let last = points.last else { return false }
        return first.distance(to: last) <= 40
    }
}
