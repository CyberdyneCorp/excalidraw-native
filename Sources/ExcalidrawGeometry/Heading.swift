import ExcalidrawMath
import Foundation

/// One of the four cardinal directions an elbow-arrow segment can travel
/// (`packages/element/src/heading.ts`).
public enum Heading: Equatable, Sendable {
    case up, right, down, left

    /// Unit vector for the heading (y-down coordinates).
    public var vector: Vector {
        switch self {
        case .up: Vector(0, -1)
        case .right: Vector(1, 0)
        case .down: Vector(0, 1)
        case .left: Vector(-1, 0)
        }
    }

    public var isHorizontal: Bool {
        self == .left || self == .right
    }

    public var isVertical: Bool {
        !isHorizontal
    }

    /// The opposite heading (`flipHeading`).
    public func flipped() -> Heading {
        switch self {
        case .up: .down
        case .right: .left
        case .down: .up
        case .left: .right
        }
    }

    /// Quantize an arbitrary vector to the nearest cardinal heading
    /// (`vectorToHeading`).
    public static func from(vector v: Vector) -> Heading {
        let x = v.u, y = v.v
        let absX = abs(x), absY = abs(y)
        if x > absY { return .right }
        if x <= -absY { return .left }
        if y > absX { return .down }
        return .up
    }

    /// Heading from `origin` toward `point` (`headingForPoint`).
    public static func from(point: Point, origin: Point) -> Heading {
        from(vector: Vector(point.x - origin.x, point.y - origin.y))
    }

    /// The side of `box` that `point` lies toward, using the diagonal search
    /// cones of `headingForPointFromElement` (rectangle case).
    public static func from(box: BoundingBox, toward point: Point) -> Heading {
        let cx = (box.minX + box.maxX) / 2
        let cy = (box.minY + box.maxY) / 2
        let hw = max(box.width / 2, 1e-9)
        let hh = max(box.height / 2, 1e-9)
        // Normalize into a unit square so the box diagonals become y = ±x; the
        // larger normalized component picks the side.
        let nx = (point.x - cx) / hw
        let ny = (point.y - cy) / hh
        if abs(nx) > abs(ny) { return nx > 0 ? .right : .left }
        return ny > 0 ? .down : .up
    }
}
