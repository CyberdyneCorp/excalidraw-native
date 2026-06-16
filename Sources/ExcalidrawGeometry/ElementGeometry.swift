import ExcalidrawMath
import ExcalidrawModel
import Foundation

/// Element-aware geometry: absolute coordinates, bounds (rotation-aware), and
/// outline extraction. Ports the bounds logic from
/// `packages/element/src/bounds.ts`.
///
/// Scope note: linear/arrow bounds and outlines use the element's point
/// polyline directly. For straight segments this is exact; for curved
/// (rounded) arrows it is the control-polygon approximation — exact cubic-Bézier
/// bounds arrive with the rough.js shape port (later phase).
public enum ElementGeometry {
    /// `[x1, y1, x2, y2, cx, cy]` in scene coordinates (`getElementAbsoluteCoords`).
    public static func absoluteCoords(_ element: ExcalidrawElement) -> (
        x1: Double, y1: Double, x2: Double, y2: Double, cx: Double, cy: Double
    ) {
        let base = element.base
        if let pts = scenePoints(element), !pts.isEmpty,
           case let kind = element.kind, isPolylineKind(kind) {
            let box = BoundingBox(points: pts)!
            return (
                box.minX,
                box.minY,
                box.maxX,
                box.maxY,
                (box.minX + box.maxX) / 2,
                (box.minY + box.maxY) / 2
            )
        }
        let x1 = base.x, y1 = base.y
        let x2 = base.x + base.width, y2 = base.y + base.height
        return (x1, y1, x2, y2, (x1 + x2) / 2, (y1 + y2) / 2)
    }

    /// Bounding box of the element. When `nonRotated` is true the element's own
    /// rotation is ignored (`getElementBounds` / `ElementBounds.calculateBounds`).
    public static func bounds(_ element: ExcalidrawElement, nonRotated: Bool = false) -> BoundingBox {
        let (x1, y1, x2, y2, cx, cy) = absoluteCoords(element)
        if nonRotated || element.base.angle == 0 {
            return BoundingBox(minX: x1, minY: y1, maxX: x2, maxY: y2)
        }
        let angle = element.base.angle
        let center = Point(cx, cy)

        switch element.kind {
        case .freedraw, .line, .arrow:
            let rotated = (scenePoints(element) ?? []).map { $0.rotated(around: center, by: angle) }
            return BoundingBox(points: rotated) ?? BoundingBox(minX: x1, minY: y1, maxX: x2, maxY: y2)
        case .ellipse:
            let w = (x2 - x1) / 2
            let h = (y2 - y1) / 2
            let ww = hypot(w * cos(angle), h * sin(angle))
            let hh = hypot(h * cos(angle), w * sin(angle))
            return BoundingBox(minX: cx - ww, minY: cy - hh, maxX: cx + ww, maxY: cy + hh)
        default:
            let corners = unrotatedOutline(element).points.map { $0.rotated(around: center, by: angle) }
            return BoundingBox(points: corners) ?? BoundingBox(minX: x1, minY: y1, maxX: x2, maxY: y2)
        }
    }

    /// Combined bounds of several elements (`getCommonBounds`). `nil` if empty.
    public static func commonBounds(_ elements: [ExcalidrawElement]) -> BoundingBox? {
        guard !elements.isEmpty else { return nil }
        return elements.reduce(nil) { acc, element in
            let b = bounds(element)
            return acc.map { $0.union(b) } ?? b
        }
    }

    // MARK: Outline

    /// An element's outline as unrotated scene-space vertices, plus whether the
    /// path is closed (forms an interior).
    struct Outline {
        var points: [Point]
        var closed: Bool
    }

    static func unrotatedOutline(_ element: ExcalidrawElement) -> Outline {
        let base = element.base
        let x1 = base.x, y1 = base.y
        let x2 = base.x + base.width, y2 = base.y + base.height
        let cx = (x1 + x2) / 2, cy = (y1 + y2) / 2

        switch element.kind {
        case .diamond:
            return Outline(points: [Point(cx, y1), Point(x2, cy), Point(cx, y2), Point(x1, cy)], closed: true)
        case let .line(props):
            let pts = props.points.map { Point(base.x + $0.x, base.y + $0.y) }
            return Outline(points: pts, closed: props.polygon || isPathALoop(props.points))
        case .arrow:
            let pts = (scenePoints(element) ?? [])
            return Outline(points: pts, closed: false)
        case let .freedraw(props):
            let pts = props.points.map { Point(base.x + $0.x, base.y + $0.y) }
            return Outline(points: pts, closed: isPathALoop(props.points))
        case .ellipse:
            // Ellipses are handled analytically, not as a polygon.
            return Outline(points: [Point(x1, y1), Point(x2, y1), Point(x2, y2), Point(x1, y2)], closed: true)
        default:
            return Outline(points: [Point(x1, y1), Point(x2, y1), Point(x2, y2), Point(x1, y2)], closed: true)
        }
    }

    // MARK: Helpers

    /// Whether a path of linear points is closed (`isPathALoop`): ≥3 points and
    /// endpoints within `LINE_CONFIRM_THRESHOLD`.
    static func isPathALoop(_ points: [Point]) -> Bool {
        guard points.count >= 3, let first = points.first, let last = points.last else { return false }
        return first.distance(to: last) <= Constants.lineConfirmThreshold
    }

    /// Scene-space points for polyline elements (freedraw/line/arrow), else nil.
    static func scenePoints(_ element: ExcalidrawElement) -> [Point]? {
        let base = element.base
        switch element.kind {
        case let .freedraw(props): return props.points.map { Point(base.x + $0.x, base.y + $0.y) }
        case let .line(props): return props.points.map { Point(base.x + $0.x, base.y + $0.y) }
        case let .arrow(props): return props.points.map { Point(base.x + $0.x, base.y + $0.y) }
        default: return nil
        }
    }

    private static func isPolylineKind(_ kind: ElementKind) -> Bool {
        switch kind {
        case .freedraw, .line, .arrow: true
        default: false
        }
    }

    public enum Constants {
        public static let lineConfirmThreshold = 40.0
    }
}
