import Foundation

/// A bounded line segment between two endpoints (`packages/math/src/segment.ts`).
public struct LineSegment: Equatable, Sendable {
    public var a: Point
    public var b: Point

    public init(_ a: Point, _ b: Point) {
        self.a = a
        self.b = b
    }

    /// Rotate the segment about `origin` (defaults to its midpoint)
    /// (`lineSegmentRotate`).
    public func rotated(by angle: Double, around origin: Point? = nil) -> LineSegment {
        let center = origin ?? a.midpoint(to: b)
        return LineSegment(a.rotated(around: center, by: angle), b.rotated(around: center, by: angle))
    }

    /// Shortest distance from `point` to the segment (`distanceToLineSegment`).
    public func distance(to point: Point) -> Double {
        let aToP = Vector(point.x - a.x, point.y - a.y)
        let aToB = Vector(b.x - a.x, b.y - a.y)
        let lenSq = aToB.magnitudeSquared
        var param = -1.0
        if lenSq != 0 { param = aToP.dot(aToB) / lenSq }

        let closest: Point = if param < 0 {
            a
        } else if param > 1 {
            b
        } else {
            Point(a.x + param * aToB.u, a.y + param * aToB.v)
        }
        return point.distance(to: closest)
    }

    /// Whether `point` lies on the segment within `threshold` (`pointOnLineSegment`).
    public func contains(_ point: Point, threshold: Double = ExcalidrawMath.precision) -> Bool {
        let d = distance(to: point)
        return d == 0 || d < threshold
    }

    /// Intersection point of two segments, or `nil` (`segmentsIntersectAt`).
    /// Preserves upstream's half-open `[0, 1)` parameter ranges.
    public func intersection(with other: LineSegment) -> Point? {
        let a0 = Vector(from: a)
        let a1 = Vector(from: b)
        let b0 = Vector(from: other.a)
        let b1 = Vector(from: other.b)
        let r = a1 - a0
        let s = b1 - b0
        let denominator = r.cross(s)
        guard denominator != 0 else { return nil }

        let i = b0 - a0
        let u = i.cross(r) / denominator
        let t = i.cross(s) / denominator
        guard u != 0 else { return nil }

        if t >= 0, t < 1, u >= 0, u < 1 {
            return (a0 + r.scaled(by: t)).point()
        }
        return nil
    }

    /// Intersection treating both segments as the lines through their endpoints,
    /// but only returning a point that lies on both segments
    /// (`lineSegmentIntersectionPoints`).
    public func lineIntersection(with other: LineSegment, threshold: Double = ExcalidrawMath.precision) -> Point? {
        guard let candidate = Line(a, b).intersection(with: Line(other.a, other.b)) else { return nil }
        guard other.contains(candidate, threshold: threshold), contains(candidate, threshold: threshold) else {
            return nil
        }
        return candidate
    }

    /// Shortest distance between two segments (`lineSegmentsDistance`).
    public func distance(to other: LineSegment) -> Double {
        if lineIntersection(with: other) != nil { return 0 }
        return Swift.min(
            other.distance(to: a),
            other.distance(to: b),
            distance(to: other.a),
            distance(to: other.b)
        )
    }
}
