import CoreGraphics
import Foundation

/// Converts generated rough.js ops into Core Graphics paths for rendering.
public enum RoughPath {
    /// Build a `CGPath` from a set of path operations.
    public static func cgPath(from ops: [PathOp]) -> CGPath {
        let path = CGMutablePath()
        var hasCurrentPoint = false
        for op in ops {
            switch op {
            case let .move(p):
                path.move(to: CGPoint(x: p.x, y: p.y))
                hasCurrentPoint = true
            case let .lineTo(p):
                if hasCurrentPoint {
                    path.addLine(to: CGPoint(x: p.x, y: p.y))
                } else {
                    path.move(to: CGPoint(x: p.x, y: p.y))
                    hasCurrentPoint = true
                }
            case let .bcurveTo(c1, c2, end):
                if !hasCurrentPoint {
                    // Defensive: a curve with no current point starts at its first control.
                    path.move(to: CGPoint(x: c1.x, y: c1.y))
                    hasCurrentPoint = true
                }
                path.addCurve(
                    to: CGPoint(x: end.x, y: end.y),
                    control1: CGPoint(x: c1.x, y: c1.y),
                    control2: CGPoint(x: c2.x, y: c2.y)
                )
            }
        }
        return path
    }

    /// Combined path for all `.path` (outline) op-sets of a drawable.
    public static func outlinePath(for drawable: Drawable) -> CGPath {
        let path = CGMutablePath()
        for set in drawable.sets where set.type == .path {
            path.addPath(cgPath(from: set.ops))
        }
        return path
    }
}
