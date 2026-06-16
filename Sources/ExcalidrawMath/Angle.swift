import Foundation

/// Angle helpers (`packages/math/src/angle.ts`). Angles are radians unless the
/// name says otherwise; one full turn is `2π`.
public enum Angle {
    /// Wrap an angle into `[0, 2π)` (`normalizeRadians`).
    public static func normalizeRadians(_ angle: Double) -> Double {
        let twoPi = 2 * Double.pi
        let remainder = angle.truncatingRemainder(dividingBy: twoPi)
        return angle < 0 ? remainder + twoPi : remainder
    }

    public static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    public static func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }

    /// Polar coordinates `(radius, angle)` of a cartesian point about the origin
    /// (`cartesian2Polar`).
    public static func cartesianToPolar(_ point: Point) -> (radius: Double, angle: Double) {
        (hypot(point.x, point.y), normalizeRadians(atan2(point.y, point.x)))
    }

    /// Whether `radians` is (close to) a right angle (`isRightAngleRads`).
    public static func isRightAngle(_ radians: Double) -> Bool {
        abs(sin(2 * radians)) < ExcalidrawMath.precision
    }

    /// Whether `angle` lies within `[min, max]`, accounting for wrap-around
    /// (`radiansBetweenAngles`).
    public static func radiansBetween(_ angle: Double, min: Double, max: Double) -> Bool {
        let a = normalizeRadians(angle)
        let lo = normalizeRadians(min)
        let hi = normalizeRadians(max)
        if lo < hi { return a >= lo && a <= hi }
        return a >= lo || a <= hi // range wraps past 0
    }

    /// Smallest absolute difference between two angles (`radiansDifference`).
    public static func radiansDifference(_ a: Double, _ b: Double) -> Double {
        var diff = normalizeRadians(a) - normalizeRadians(b)
        if diff < -Double.pi {
            diff += 2 * .pi
        } else if diff > Double.pi {
            diff -= 2 * .pi
        }
        return abs(diff)
    }
}
