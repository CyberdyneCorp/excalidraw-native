import Foundation

/// A closed polygon (`packages/math/src/polygon.ts`). The stored `points` are
/// closed: the first point is repeated as the last when needed.
public struct Polygon: Equatable, Sendable {
    public let points: [Point]

    public init(_ points: [Point]) {
        self.points = Polygon.closed(points)
    }

    private static func closed(_ points: [Point]) -> [Point] {
        guard let first = points.first, let last = points.last else { return points }
        return first.isApproximatelyEqual(to: last) ? points : points + [first]
    }

    /// Even-odd ray-casting containment test (`polygonIncludesPoint`).
    public func includes(_ point: Point) -> Bool {
        let x = point.x
        let y = point.y
        var inside = false
        var j = points.count - 1
        for i in 0 ..< points.count {
            let xi = points[i].x, yi = points[i].y
            let xj = points[j].x, yj = points[j].y
            if (yi > y && yj <= y) || (yi <= y && yj > y),
               x < (xj - xi) * (y - yi) / (yj - yi) + xi {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Non-zero winding-number containment test (`polygonIncludesPointNonZero`).
    public func includesNonZero(_ point: Point) -> Bool {
        let x = point.x
        let y = point.y
        var winding = 0
        for i in 0 ..< points.count {
            let j = (i + 1) % points.count
            let xi = points[i].x, yi = points[i].y
            let xj = points[j].x, yj = points[j].y
            if yi <= y {
                if yj > y, (xj - xi) * (y - yi) - (x - xi) * (yj - yi) > 0 {
                    winding += 1
                }
            } else if yj <= y, (xj - xi) * (y - yi) - (x - xi) * (yj - yi) < 0 {
                winding -= 1
            }
        }
        return winding != 0
    }

    /// Whether `point` lies on any edge within `threshold` (`pointOnPolygon`).
    public func contains(_ point: Point, threshold: Double = ExcalidrawMath.precision) -> Bool {
        guard points.count >= 2 else { return false }
        for i in 0 ..< (points.count - 1) where
            LineSegment(points[i], points[i + 1]).contains(point, threshold: threshold) {
            return true
        }
        return false
    }
}
