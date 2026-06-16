import Foundation

/// A 2D vector (`packages/math/src/vector.ts`).
public struct Vector: Equatable, Hashable, Sendable {
    public var u: Double
    public var v: Double

    public init(_ u: Double, _ v: Double) {
        self.u = u
        self.v = v
    }

    /// Vector from `origin` to `point` (`vectorFromPoint`).
    public init(from point: Point, origin: Point = .zero) {
        self.init(point.x - origin.x, point.y - origin.y)
    }

    public static let zero = Vector(0, 0)

    public static func + (lhs: Vector, rhs: Vector) -> Vector {
        Vector(lhs.u + rhs.u, lhs.v + rhs.v)
    }

    public static func - (lhs: Vector, rhs: Vector) -> Vector {
        Vector(lhs.u - rhs.u, lhs.v - rhs.v)
    }

    public func scaled(by scalar: Double) -> Vector {
        Vector(u * scalar, v * scalar)
    }

    /// 2D cross product (the scalar z-component) (`vectorCross`).
    public func cross(_ other: Vector) -> Double {
        u * other.v - other.u * v
    }

    /// Dot product (`vectorDot`).
    public func dot(_ other: Vector) -> Double {
        u * other.u + v * other.v
    }

    public var magnitudeSquared: Double {
        u * u + v * v
    }

    public var magnitude: Double {
        magnitudeSquared.squareRoot()
    }

    /// Unit vector, or the zero vector when the magnitude is zero (`vectorNormalize`).
    public func normalized() -> Vector {
        let m = magnitude
        return m == 0 ? .zero : Vector(u / m, v / m)
    }

    /// Right-hand normal (`vectorNormal`).
    public func normal() -> Vector {
        Vector(v, -u)
    }

    /// The point this vector points at from `offset` (`pointFromVector`).
    public func point(offset: Point = .zero) -> Point {
        Point(offset.x + u, offset.y + v)
    }
}
