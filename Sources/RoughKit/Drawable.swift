import ExcalidrawMath
import Foundation

/// A single path operation, mirroring rough.js `Op` (`move` / `lineTo` /
/// `bcurveTo`). rough.js renders hand-drawn strokes almost entirely as cubic
/// Bézier segments (`bcurveTo`).
public enum PathOp: Equatable, Sendable {
    case move(Point)
    case lineTo(Point)
    /// Cubic Bézier: two control points then the end point.
    case bcurveTo(Point, Point, Point)
}

/// What a set of ops represents (rough.js `OpSetType`).
public enum OpSetType: String, Sendable {
    case path // stroked outline
    case fillSketch // hachure/zigzag fill strokes
    case fillPath // solid fill region
}

/// A group of path operations of one type (rough.js `OpSet`).
public struct OpSet: Equatable, Sendable {
    public var type: OpSetType
    public var ops: [PathOp]

    public init(type: OpSetType, ops: [PathOp]) {
        self.type = type
        self.ops = ops
    }
}

/// The generated drawable for a shape: the sets of operations plus the options
/// used to produce them (rough.js `Drawable`).
public struct Drawable: Equatable, Sendable {
    public var shape: String
    public var sets: [OpSet]
    public var options: RoughOptions

    public init(shape: String, sets: [OpSet], options: RoughOptions) {
        self.shape = shape
        self.sets = sets
        self.options = options
    }
}
