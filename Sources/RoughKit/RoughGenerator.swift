import ExcalidrawMath
import Foundation

/// Generates rough.js-style hand-drawn shape geometry. Ports the stroke
/// primitives from rough.js `renderer.ts` (`_line`, `_doubleLine`,
/// `_linearPath`) and the polygon/rectangle generators.
///
/// All ops for one shape share a single RNG seeded by `options.seed`, exactly as
/// rough.js does (one lazily-created `Random` per drawable). The outline is
/// generated before any fill, so outline geometry is independent of fill.
///
/// Scope: this increment covers straight-stroke shapes (line, polyline,
/// polygon, rectangle). Ellipse/curve generation and fill styles (hachure,
/// solid, zigzag, cross-hatch) are the next Phase 2 increment.
public struct RoughGenerator: Sendable {
    public init() {}

    // MARK: Public shape API

    public func line(_ a: Point, _ b: Point, options: RoughOptions) -> Drawable {
        var rng = SeededRandom(seed: options.seed)
        let ops = doubleLine(a.x, a.y, b.x, b.y, options, filling: false, &rng)
        return Drawable(shape: "line", sets: [OpSet(type: .path, ops: ops)], options: options)
    }

    /// Open polyline through `points`.
    public func linearPath(_ points: [Point], options: RoughOptions) -> Drawable {
        var rng = SeededRandom(seed: options.seed)
        let ops = linearPathOps(points, close: false, options, &rng)
        return Drawable(shape: "linearPath", sets: [OpSet(type: .path, ops: ops)], options: options)
    }

    /// Closed polygon through `points`.
    public func polygon(_ points: [Point], options: RoughOptions) -> Drawable {
        var rng = SeededRandom(seed: options.seed)
        let ops = linearPathOps(points, close: true, options, &rng)
        return Drawable(shape: "polygon", sets: [OpSet(type: .path, ops: ops)], options: options)
    }

    public func rectangle(x: Double, y: Double, width: Double, height: Double, options: RoughOptions) -> Drawable {
        var rng = SeededRandom(seed: options.seed)
        let pts = [Point(x, y), Point(x + width, y), Point(x + width, y + height), Point(x, y + height)]
        let ops = linearPathOps(pts, close: true, options, &rng)
        return Drawable(shape: "rectangle", sets: [OpSet(type: .path, ops: ops)], options: options)
    }

    // MARK: Stroke primitives (rough.js renderer.ts)

    func linearPathOps(_ points: [Point], close: Bool, _ o: RoughOptions, _ rng: inout SeededRandom) -> [PathOp] {
        let len = points.count
        guard len >= 2 else { return [] }
        if len == 2 {
            return doubleLine(points[0].x, points[0].y, points[1].x, points[1].y, o, filling: false, &rng)
        }
        var ops: [PathOp] = []
        for i in 0..<(len - 1) {
            ops += doubleLine(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y, o, filling: false, &rng)
        }
        if close {
            ops += doubleLine(points[len - 1].x, points[len - 1].y, points[0].x, points[0].y, o, filling: false, &rng)
        }
        return ops
    }

    func doubleLine(
        _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double,
        _ o: RoughOptions, filling: Bool, _ rng: inout SeededRandom
    ) -> [PathOp] {
        let singleStroke = filling ? o.disableMultiStrokeFill : o.disableMultiStroke
        let o1 = line(x1, y1, x2, y2, o, move: true, overlay: false, &rng)
        if singleStroke { return o1 }
        let o2 = line(x1, y1, x2, y2, o, move: true, overlay: true, &rng)
        return o1 + o2
    }

    // swiftlint:disable:next function_parameter_count
    func line(
        _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double,
        _ o: RoughOptions, move: Bool, overlay: Bool, _ rng: inout SeededRandom
    ) -> [PathOp] {
        let lengthSq = pow(x1 - x2, 2) + pow(y1 - y2, 2)
        let length = lengthSq.squareRoot()

        let roughnessGain: Double
        if length < 200 {
            roughnessGain = 1
        } else if length > 500 {
            roughnessGain = 0.4
        } else {
            roughnessGain = -0.0016668 * length + 1.233334
        }

        var offsetValue = o.maxRandomnessOffset
        if offsetValue * offsetValue * 100 > lengthSq {
            offsetValue = length / 10
        }
        let halfOffset = offsetValue / 2
        let divergePoint = 0.2 + rng.next() * 0.2

        var midDispX = o.bowing * o.maxRandomnessOffset * (y2 - y1) / 200
        var midDispY = o.bowing * o.maxRandomnessOffset * (x1 - x2) / 200
        midDispX = offsetOpt(midDispX, o, roughnessGain, &rng)
        midDispY = offsetOpt(midDispY, o, roughnessGain, &rng)

        let preserve = o.preserveVertices
        func randomHalf(_ rng: inout SeededRandom) -> Double { offsetOpt(halfOffset, o, roughnessGain, &rng) }
        func randomFull(_ rng: inout SeededRandom) -> Double { offsetOpt(offsetValue, o, roughnessGain, &rng) }

        var ops: [PathOp] = []
        if move {
            if overlay {
                let mx = preserve ? 0 : randomHalf(&rng)
                let my = preserve ? 0 : randomHalf(&rng)
                ops.append(.move(Point(x1 + mx, y1 + my)))
            } else {
                let mx = preserve ? 0 : offsetOpt(offsetValue, o, roughnessGain, &rng)
                let my = preserve ? 0 : offsetOpt(offsetValue, o, roughnessGain, &rng)
                ops.append(.move(Point(x1 + mx, y1 + my)))
            }
        }

        // rough.js evaluates the six randomized components in this exact order;
        // keep them as ordered local bindings so RNG advancement matches.
        let randomize: (inout SeededRandom) -> Double = overlay ? randomHalf : randomFull
        let c1x = midDispX + x1 + (x2 - x1) * divergePoint + randomize(&rng)
        let c1y = midDispY + y1 + (y2 - y1) * divergePoint + randomize(&rng)
        let c2x = midDispX + x1 + 2 * (x2 - x1) * divergePoint + randomize(&rng)
        let c2y = midDispY + y1 + 2 * (y2 - y1) * divergePoint + randomize(&rng)
        let ex = x2 + (preserve ? 0 : randomize(&rng))
        let ey = y2 + (preserve ? 0 : randomize(&rng))
        ops.append(.bcurveTo(Point(c1x, c1y), Point(c2x, c2y), Point(ex, ey)))
        return ops
    }

    // MARK: Offsets (rough.js `_offset` / `_offsetOpt`)

    func offset(_ min: Double, _ max: Double, _ o: RoughOptions, _ gain: Double, _ rng: inout SeededRandom) -> Double {
        o.roughness * gain * (rng.next() * (max - min) + min)
    }

    func offsetOpt(_ x: Double, _ o: RoughOptions, _ gain: Double, _ rng: inout SeededRandom) -> Double {
        offset(-x, x, o, gain, &rng)
    }
}
