import ExcalidrawMath
import ExcalidrawModel
import Foundation

/// Pointer hit-testing for elements, porting the entry logic from
/// `packages/element/src/collision.ts` (`hitElementItself`, `shouldTestInside`,
/// `isPointInElement`) and `distance.ts` (`distanceToElement`).
///
/// Scope note: shapes are tested against straight-edged outlines (rounded
/// corners are treated as sharp) and curved arrows against their point polyline.
/// This is faithful for the common cases; exact rounded-corner / cubic-Bézier
/// hit-testing arrives with the rough.js shape port.
public enum HitTest {
    /// Whether the element should be hit "from the inside" (filled / textful /
    /// closed) rather than only on its outline (`shouldTestInside`).
    public static func shouldTestInside(_ element: ExcalidrawElement) -> Bool {
        if case .arrow = element.kind { return false }

        let draggableFromInside =
            (hasBackground(element.kind) && !isTransparent(element.base.backgroundColor))
                || hasBoundText(element)
                || isIframeLike(element.kind)
                || isText(element.kind)

        switch element.kind {
        case let .line(props):
            return draggableFromInside && ElementGeometry.isPathALoop(props.points)
        case let .freedraw(props):
            return draggableFromInside && ElementGeometry.isPathALoop(props.points)
        case .image:
            return true
        default:
            return draggableFromInside
        }
    }

    /// Whether `point` (scene coords) hits the element within `threshold`
    /// (`hitElementItself`).
    public static func hit(_ element: ExcalidrawElement, at point: Point, threshold: Double) -> Bool {
        // Cheap early-out against the rotated bounding box.
        let nonRotated = ElementGeometry.bounds(element, nonRotated: true)
        guard isPointInRotatedBounds(point, nonRotated, angle: element.base.angle, tolerance: threshold) else {
            return false
        }
        if shouldTestInside(element) {
            return isPointInside(element, point: point) || isPointOnOutline(element, point: point, threshold: threshold)
        }
        return isPointOnOutline(element, point: point, threshold: threshold)
    }

    /// Strict interior test (`isPointInElement`). Open paths have no interior.
    public static func isPointInside(_ element: ExcalidrawElement, point: Point) -> Bool {
        let (x1, y1, x2, y2, cx, cy) = ElementGeometry.absoluteCoords(element)
        if case .ellipse = element.kind {
            let local = point.rotated(around: Point(cx, cy), by: -element.base.angle)
            return Ellipse(center: Point(cx, cy), halfWidth: (x2 - x1) / 2, halfHeight: (y2 - y1) / 2).includes(local)
        }
        let outline = ElementGeometry.unrotatedOutline(element)
        guard outline.closed, outline.points.count >= 3 else { return false }
        let rotated = outline.points.map { $0.rotated(around: Point(cx, cy), by: element.base.angle) }
        return Polygon(rotated).includes(point)
    }

    /// Whether `point` lies on the element outline within `threshold`
    /// (`isPointOnElementOutline`).
    public static func isPointOnOutline(_ element: ExcalidrawElement, point: Point, threshold: Double) -> Bool {
        distance(element, to: point) <= Swift.max(threshold, ExcalidrawMath.precision)
    }

    /// Shortest distance from `point` to the element outline (`distanceToElement`).
    public static func distance(_ element: ExcalidrawElement, to point: Point) -> Double {
        let (x1, y1, x2, y2, cx, cy) = ElementGeometry.absoluteCoords(element)
        let center = Point(cx, cy)
        if case .ellipse = element.kind {
            let local = point.rotated(around: center, by: -element.base.angle)
            return Ellipse(center: center, halfWidth: (x2 - x1) / 2, halfHeight: (y2 - y1) / 2).distance(from: local)
        }
        let segments = rotatedSegments(element, center: center)
        guard let first = segments.first else {
            // Degenerate (single point) element.
            let outline = ElementGeometry.unrotatedOutline(element)
            return outline.points.first.map {
                $0.rotated(around: center, by: element.base.angle).distance(to: point)
            } ?? Swift.min(abs(point.x - x1), abs(point.y - y1))
        }
        return segments.dropFirst().reduce(first.distance(to: point)) { acc, segment in
            Swift.min(acc, segment.distance(to: point))
        }
    }

    // MARK: Internals

    static func rotatedSegments(_ element: ExcalidrawElement, center: Point) -> [LineSegment] {
        let outline = ElementGeometry.unrotatedOutline(element)
        let pts = outline.points.map { $0.rotated(around: center, by: element.base.angle) }
        guard pts.count >= 2 else { return [] }
        var segments: [LineSegment] = []
        for i in 0 ..< (pts.count - 1) {
            segments.append(LineSegment(pts[i], pts[i + 1]))
        }
        if outline.closed, let first = pts.first, let last = pts.last, first != last {
            segments.append(LineSegment(last, first))
        }
        return segments
    }

    static func isPointInRotatedBounds(
        _ point: Point, _ bounds: BoundingBox, angle: Double, tolerance: Double
    ) -> Bool {
        let center = Point((bounds.minX + bounds.maxX) / 2, (bounds.minY + bounds.maxY) / 2)
        let adjusted = angle == 0 ? point : point.rotated(around: center, by: -angle)
        return adjusted.isWithin(
            Point(bounds.minX - tolerance, bounds.minY - tolerance),
            Point(bounds.maxX + tolerance, bounds.maxY + tolerance)
        )
    }

    private static func hasBackground(_ kind: ElementKind) -> Bool {
        switch kind {
        case .rectangle, .iframe, .embeddable, .ellipse, .diamond, .line, .freedraw: true
        default: false
        }
    }

    private static func isTransparent(_ color: String) -> Bool {
        if color == "transparent" || color.isEmpty { return true }
        // 8-digit hex with a fully transparent alpha channel.
        return color.count == 9 && color.hasPrefix("#") && color.hasSuffix("00")
    }

    private static func hasBoundText(_ element: ExcalidrawElement) -> Bool {
        element.base.boundElements?.contains { $0.type == .text } ?? false
    }

    private static func isIframeLike(_ kind: ElementKind) -> Bool {
        switch kind {
        case .iframe, .embeddable: true
        default: false
        }
    }

    private static func isText(_ kind: ElementKind) -> Bool {
        if case .text = kind { return true }
        return false
    }
}
