import ExcalidrawMath
import Foundation

/// Ellipse and open-curve generation, porting rough.js `_curve`,
/// `_curveWithOffset`, `generateEllipseParams`, `ellipseWithParams`, and
/// `_computeEllipsePoints`.
///
/// Every randomized term is bound to a sequential `let` so the RNG advances in
/// the same order as rough.js (and to satisfy Swift's exclusive-access rule on
/// the shared generator). Exact numeric parity with the JS implementation is
/// pending validation against reference output; geometry is faithful in form.
public extension RoughGenerator {
    /// A smooth multi-stroke curve through `points` (rough.js `curve`).
    func curve(_ points: [Point], options: RoughOptions) -> Drawable {
        var rng = SeededRandom(seed: options.seed)
        var ops = curveWithOffset(points, offsetAmount: 1 * (1 + options.roughness * 0.2), options, &rng)
        if !options.disableMultiStroke, options.roughness != 0 {
            // rough.js clones options with seed + 1 for the overlay stroke.
            var rng2 = SeededRandom(seed: options.seed + 1)
            ops += curveWithOffset(points, offsetAmount: 1.5 * (1 + options.roughness * 0.22), options, &rng2)
        }
        return Drawable(shape: "curve", sets: [OpSet(type: .path, ops: ops)], options: options)
    }

    /// A hand-drawn ellipse inscribed in the given box (rough.js `ellipse`).
    /// `estimatedPoints` (the core polygon) is exposed for pattern fills.
    func ellipse(x: Double, y: Double, width: Double, height: Double, options: RoughOptions)
        -> (drawable: Drawable, estimatedPoints: [Point]) {
        var rng = SeededRandom(seed: options.seed)
        let params = ellipseParams(width: width, height: height, options, &rng)
        let result = ellipseWithParams(x: x, y: y, options, params, &rng)
        var sets: [OpSet] = []
        if let fill = fillOps(polygons: [result.estimatedPoints], options: options) { sets.append(fill) }
        sets.append(OpSet(type: .path, ops: result.ops))
        let drawable = Drawable(shape: "ellipse", sets: sets, options: options)
        return (drawable, result.estimatedPoints)
    }

    // MARK: Curve internals

    func curveWithOffset(
        _ points: [Point], offsetAmount: Double, _ o: RoughOptions, _ rng: inout SeededRandom
    ) -> [PathOp] {
        guard let first = points.first else { return [] }
        var ps: [Point] = []
        let s0x = first.x + jitter(offsetAmount, o, &rng)
        let s0y = first.y + jitter(offsetAmount, o, &rng)
        ps.append(Point(s0x, s0y))
        let s1x = first.x + jitter(offsetAmount, o, &rng)
        let s1y = first.y + jitter(offsetAmount, o, &rng)
        ps.append(Point(s1x, s1y))
        for i in 1 ..< points.count {
            let px = points[i].x + jitter(offsetAmount, o, &rng)
            let py = points[i].y + jitter(offsetAmount, o, &rng)
            ps.append(Point(px, py))
            if i == points.count - 1 {
                let qx = points[i].x + jitter(offsetAmount, o, &rng)
                let qy = points[i].y + jitter(offsetAmount, o, &rng)
                ps.append(Point(qx, qy))
            }
        }
        return curveOps(ps, o, &rng)
    }

    /// Catmull-Rom-style cubic curve through control points (rough.js `_curve`).
    func curveOps(_ points: [Point], _ o: RoughOptions, _ rng: inout SeededRandom) -> [PathOp] {
        let len = points.count
        var ops: [PathOp] = []
        if len > 3 {
            let s = 1 - o.curveTightness
            ops.append(.move(points[1]))
            var i = 1
            while i + 2 < len {
                let c0 = points[i]
                let c1 = Point(
                    c0.x + (s * points[i + 1].x - s * points[i - 1].x) / 6,
                    c0.y + (s * points[i + 1].y - s * points[i - 1].y) / 6
                )
                let c2 = Point(
                    points[i + 1].x + (s * points[i].x - s * points[i + 2].x) / 6,
                    points[i + 1].y + (s * points[i].y - s * points[i + 2].y) / 6
                )
                ops.append(.bcurveTo(c1, c2, points[i + 1]))
                i += 1
            }
        } else if len == 3 {
            ops.append(.move(points[1]))
            ops.append(.bcurveTo(points[1], points[2], points[2]))
        } else if len == 2 {
            ops += doubleLine(points[0].x, points[0].y, points[1].x, points[1].y, o, filling: false, &rng)
        }
        return ops
    }

    // MARK: Ellipse internals

    private func ellipseParams(
        width: Double, height: Double, _ o: RoughOptions, _ rng: inout SeededRandom
    ) -> (increment: Double, rx: Double, ry: Double) {
        let psq = (.pi * 2 * (((width / 2) * (width / 2) + (height / 2) * (height / 2)) / 2).squareRoot()).squareRoot()
        let stepCount = Swift.max(o.curveStepCount, (o.curveStepCount / 200.0.squareRoot()) * psq).rounded(.up)
        let increment = (.pi * 2) / stepCount
        let curveFitRandomness = 1 - o.curveFitting
        var rx = abs(width / 2)
        var ry = abs(height / 2)
        rx += offsetOpt(rx * curveFitRandomness, o, 1, &rng)
        ry += offsetOpt(ry * curveFitRandomness, o, 1, &rng)
        return (increment, rx, ry)
    }

    private func ellipseWithParams(
        x: Double, y: Double, _ o: RoughOptions,
        _ p: (increment: Double, rx: Double, ry: Double), _ rng: inout SeededRandom
    ) -> (estimatedPoints: [Point], ops: [PathOp]) {
        let inner = offset(0.4, 1, o, 1, &rng)
        let overlapBase = offset(0.1, inner, o, 1, &rng)
        let overlap = p.increment * overlapBase

        let first = computeEllipsePoints(
            increment: p.increment, cx: x, cy: y, rx: p.rx, ry: p.ry,
            offsetAmount: 1, overlap: overlap, o, &rng
        )
        var ops = curveOps(first.all, o, &rng)
        if !o.disableMultiStroke, o.roughness != 0 {
            let second = computeEllipsePoints(
                increment: p.increment, cx: x, cy: y, rx: p.rx, ry: p.ry,
                offsetAmount: 1.5, overlap: 0, o, &rng
            )
            ops += curveOps(second.all, o, &rng)
        }
        return (first.core, ops)
    }

    // swiftlint:disable:next function_parameter_count
    private func computeEllipsePoints(
        increment incr0: Double, cx: Double, cy: Double, rx: Double, ry: Double,
        offsetAmount: Double, overlap: Double, _ o: RoughOptions, _ rng: inout SeededRandom
    ) -> (all: [Point], core: [Point]) {
        var core: [Point] = []
        var all: [Point] = []

        if o.roughness == 0 {
            let increment = incr0 / 4
            all.append(Point(cx + rx * cos(-increment), cy + ry * sin(-increment)))
            var angle = 0.0
            while angle <= .pi * 2 {
                let p = Point(cx + rx * cos(angle), cy + ry * sin(angle))
                core.append(p)
                all.append(p)
                angle += increment
            }
            all.append(Point(cx + rx, cy)) // cos(0)=1, sin(0)=0
            all.append(Point(cx + rx * cos(increment), cy + ry * sin(increment)))
            return (all, core)
        }

        let increment = incr0
        let radOffset = offsetOpt(0.5, o, 1, &rng) - .pi / 2

        let p0x = jitter(offsetAmount, o, &rng) + cx + 0.9 * rx * cos(radOffset - increment)
        let p0y = jitter(offsetAmount, o, &rng) + cy + 0.9 * ry * sin(radOffset - increment)
        all.append(Point(p0x, p0y))

        let endAngle = .pi * 2 + radOffset - 0.01
        var angle = radOffset
        while angle < endAngle {
            let px = jitter(offsetAmount, o, &rng) + cx + rx * cos(angle)
            let py = jitter(offsetAmount, o, &rng) + cy + ry * sin(angle)
            let p = Point(px, py)
            core.append(p)
            all.append(p)
            angle += increment
        }

        let e1x = jitter(offsetAmount, o, &rng); let e1y = jitter(offsetAmount, o, &rng)
        all.append(Point(
            e1x + cx + rx * cos(radOffset + .pi * 2 + overlap * 0.5),
            e1y + cy + ry * sin(radOffset + .pi * 2 + overlap * 0.5)
        ))
        let e2x = jitter(offsetAmount, o, &rng); let e2y = jitter(offsetAmount, o, &rng)
        all.append(Point(
            e2x + cx + 0.98 * rx * cos(radOffset + overlap),
            e2y + cy + 0.98 * ry * sin(radOffset + overlap)
        ))
        let e3x = jitter(offsetAmount, o, &rng); let e3y = jitter(offsetAmount, o, &rng)
        all.append(Point(
            e3x + cx + 0.9 * rx * cos(radOffset + overlap * 0.5),
            e3y + cy + 0.9 * ry * sin(radOffset + overlap * 0.5)
        ))
        return (all, core)
    }

    /// `_offsetOpt(x)` — one randomized perturbation in `[-x, x]`.
    private func jitter(_ x: Double, _ o: RoughOptions, _ rng: inout SeededRandom) -> Double {
        offsetOpt(x, o, 1, &rng)
    }
}
