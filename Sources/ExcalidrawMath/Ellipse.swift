import Foundation

/// An axis-aligned ellipse given by its center and half-extents
/// (`packages/math/src/ellipse.ts`).
public struct Ellipse: Equatable, Sendable {
    public var center: Point
    public var halfWidth: Double
    public var halfHeight: Double

    public init(center: Point, halfWidth: Double, halfHeight: Double) {
        self.center = center
        self.halfWidth = halfWidth
        self.halfHeight = halfHeight
    }

    /// Whether `p` is inside or on the ellipse (`ellipseIncludesPoint`).
    public func includes(_ p: Point) -> Bool {
        let nx = (p.x - center.x) / halfWidth
        let ny = (p.y - center.y) / halfHeight
        return nx * nx + ny * ny <= 1
    }

    /// Whether `p` lies on the outline within `threshold` (`ellipseTouchesPoint`).
    public func touches(_ p: Point, threshold: Double = ExcalidrawMath.precision) -> Bool {
        distance(from: p) <= threshold
    }

    /// Shortest distance from `p` to the ellipse outline, via three Newton
    /// iterations in the first quadrant (`ellipseDistanceFromPoint`).
    public func distance(from p: Point) -> Double {
        let a = halfWidth
        let b = halfHeight
        let translated = Vector(from: p) - Vector(from: center)
        let px = abs(translated.u)
        let py = abs(translated.v)

        var tx = 0.707
        var ty = 0.707
        for _ in 0 ..< 3 {
            let x = a * tx
            let y = b * ty
            let ex = (a * a - b * b) * (tx * tx * tx) / a
            let ey = (b * b - a * a) * (ty * ty * ty) / b
            let rx = x - ex
            let ry = y - ey
            let qx = px - ex
            let qy = py - ey
            let r = hypot(ry, rx)
            let q = hypot(qy, qx)
            tx = Swift.min(1, Swift.max(0, (qx * r / q + ex) / a))
            ty = Swift.min(1, Swift.max(0, (qy * r / q + ey) / b))
            let t = hypot(ty, tx)
            tx /= t
            ty /= t
        }

        let closest = Point(a * tx * Self.sign(translated.u), b * ty * Self.sign(translated.v))
        return translated.point().distance(to: closest)
    }

    /// Up to two intersection points of a segment with the ellipse
    /// (`ellipseSegmentInterceptPoints`).
    public func intersection(with s: LineSegment) -> [Point] {
        let rx = halfWidth
        let ry = halfHeight
        let dir = Vector(from: s.b, origin: s.a)
        let diff = Vector(s.a.x - center.x, s.a.y - center.y)
        let mDir = Vector(dir.u / (rx * rx), dir.v / (ry * ry))
        let mDiff = Vector(diff.u / (rx * rx), diff.v / (ry * ry))

        let a = dir.dot(mDir)
        let b = dir.dot(mDiff)
        let c = diff.dot(mDiff) - 1
        let d = b * b - a * c

        func pointAt(_ t: Double) -> Point {
            Point(s.a.x + (s.b.x - s.a.x) * t, s.a.y + (s.b.y - s.a.y) * t)
        }

        var result: [Point] = []
        if d > 0 {
            let ta = (-b - d.squareRoot()) / a
            let tb = (-b + d.squareRoot()) / a
            if ta >= 0, ta <= 1 { result.append(pointAt(ta)) }
            if tb >= 0, tb <= 1 { result.append(pointAt(tb)) }
        } else if d == 0 {
            let t = -b / a
            if t >= 0, t <= 1 { result.append(pointAt(t)) }
        }
        return result
    }

    /// Intersection points of an infinite line with the ellipse
    /// (`ellipseLineIntersectionPoints`).
    public func intersection(with line: Line) -> [Point] {
        let x1 = line.p.x - center.x
        let y1 = line.p.y - center.y
        let x2 = line.q.x - center.x
        let y2 = line.q.y - center.y
        let a = pow(x2 - x1, 2) / pow(halfWidth, 2) + pow(y2 - y1, 2) / pow(halfHeight, 2)
        let b = 2 * (x1 * (x2 - x1) / pow(halfWidth, 2) + y1 * (y2 - y1) / pow(halfHeight, 2))
        let c = pow(x1, 2) / pow(halfWidth, 2) + pow(y1, 2) / pow(halfHeight, 2) - 1
        let disc = b * b - 4 * a * c
        let t1 = (-b + disc.squareRoot()) / (2 * a)
        let t2 = (-b - disc.squareRoot()) / (2 * a)
        let candidates = [
            Point(x1 + t1 * (x2 - x1) + center.x, y1 + t1 * (y2 - y1) + center.y),
            Point(x1 + t2 * (x2 - x1) + center.x, y1 + t2 * (y2 - y1) + center.y)
        ].filter { !$0.x.isNaN && !$0.y.isNaN }

        if candidates.count == 2, candidates[0].isApproximatelyEqual(to: candidates[1]) {
            return [candidates[0]]
        }
        return candidates
    }

    private static func sign(_ value: Double) -> Double {
        value > 0 ? 1 : (value < 0 ? -1 : 0)
    }
}
