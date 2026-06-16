import Foundation

/// An axis-aligned rectangle defined by two opposite corners
/// (`packages/math/src/rectangle.ts`).
public struct Rectangle: Equatable, Sendable {
    public var topLeft: Point
    public var bottomRight: Point

    public init(topLeft: Point, bottomRight: Point) {
        self.topLeft = topLeft
        self.bottomRight = bottomRight
    }

    /// Build from min/max bounds (`rectangleFromNumberSequence`).
    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.init(topLeft: Point(minX, minY), bottomRight: Point(maxX, maxY))
    }

    /// Intersection points of the rectangle's four edges with a segment
    /// (`rectangleIntersectLineSegment`).
    public func intersection(with segment: LineSegment) -> [Point] {
        let topRight = Point(bottomRight.x, topLeft.y)
        let bottomLeft = Point(topLeft.x, bottomRight.y)
        let edges = [
            LineSegment(topLeft, topRight),
            LineSegment(topRight, bottomRight),
            LineSegment(bottomRight, bottomLeft),
            LineSegment(bottomLeft, topLeft)
        ]
        return edges.compactMap { segment.lineIntersection(with: $0) }
    }

    /// Whether two rectangles overlap (`rectangleIntersectRectangle`).
    public func intersects(_ other: Rectangle) -> Bool {
        topLeft.x < other.bottomRight.x && bottomRight.x > other.topLeft.x &&
            topLeft.y < other.bottomRight.y && bottomRight.y > other.topLeft.y
    }
}
