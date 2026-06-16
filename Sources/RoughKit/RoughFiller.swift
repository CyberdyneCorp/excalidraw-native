import ExcalidrawMath
import Foundation

/// Fill generation for shapes, porting rough.js fillers: solid polygon fill,
/// hachure (rotated scanline hatching), cross-hatch (hachure ×2 perpendicular),
/// and zigzag. Produces a `fillPath` (solid) or `fillSketch` (line patterns)
/// op-set to be drawn beneath the outline.
public extension RoughGenerator {
    /// Build the fill op-set for one or more polygon rings, or `nil` when there
    /// is no fill. `seed` drives deterministic sketch jitter.
    func fillOps(polygons: [[Point]], options o: RoughOptions) -> OpSet? {
        guard o.fill != nil, !polygons.isEmpty else { return nil }
        switch o.fillStyle {
        case "solid":
            return solidFill(polygons)
        case "zigzag":
            return zigzagFill(polygons, o)
        case "cross-hatch":
            return crossHatchFill(polygons, o)
        default: // "hachure"
            return hachureFill(polygons, o)
        }
    }

    // MARK: Solid

    private func solidFill(_ polygons: [[Point]]) -> OpSet {
        var ops: [PathOp] = []
        for poly in polygons where poly.count > 2 {
            ops.append(.move(poly[0]))
            for i in 1 ..< poly.count {
                ops.append(.lineTo(poly[i]))
            }
            ops.append(.lineTo(poly[0])) // close
        }
        return OpSet(type: .fillPath, ops: ops)
    }

    // MARK: Hachure family

    private func hachureFill(_ polygons: [[Point]], _ o: RoughOptions) -> OpSet {
        var rng = SeededRandom(seed: o.seed)
        let lines = hachureLines(polygons, gap: hachureGap(o), angleDegrees: o.hachureAngle + 90)
        return OpSet(type: .fillSketch, ops: renderLines(lines, o, &rng))
    }

    private func crossHatchFill(_ polygons: [[Point]], _ o: RoughOptions) -> OpSet {
        var rng = SeededRandom(seed: o.seed)
        let gap = hachureGap(o)
        var ops = renderLines(hachureLines(polygons, gap: gap, angleDegrees: o.hachureAngle + 90), o, &rng)
        ops += renderLines(hachureLines(polygons, gap: gap, angleDegrees: o.hachureAngle + 180), o, &rng)
        return OpSet(type: .fillSketch, ops: ops)
    }

    private func zigzagFill(_ polygons: [[Point]], _ o: RoughOptions) -> OpSet {
        var rng = SeededRandom(seed: o.seed)
        let lines = hachureLines(polygons, gap: hachureGap(o), angleDegrees: o.hachureAngle + 90)
        // Connect consecutive scanline segments into a single zigzag stroke.
        var connected: [(Point, Point)] = []
        for i in 0 ..< lines.count {
            connected.append(lines[i])
            if i + 1 < lines.count {
                connected.append((lines[i].1, lines[i + 1].0))
            }
        }
        return OpSet(type: .fillSketch, ops: renderLines(connected, o, &rng))
    }

    private func hachureGap(_ o: RoughOptions) -> Double {
        let gap = o.hachureGap < 0 ? o.strokeWidth * 4 : o.hachureGap
        return Swift.max(gap, 0.1)
    }

    private func renderLines(_ lines: [(Point, Point)], _ o: RoughOptions, _ rng: inout SeededRandom) -> [PathOp] {
        var ops: [PathOp] = []
        for line in lines {
            ops += doubleLine(line.0.x, line.0.y, line.1.x, line.1.y, o, filling: true, &rng)
        }
        return ops
    }

    /// Rotated-scanline hatching (rough.js `polygonHachureLines` +
    /// `straightHachureLines`): rotate so hatching is horizontal, intersect
    /// evenly-spaced scanlines with the polygon edges, then rotate the resulting
    /// segments back.
    private func hachureLines(_ polygons: [[Point]], gap: Double, angleDegrees: Double) -> [(Point, Point)] {
        let rotated = polygons.map { ring in ring.map { rotate($0, byDegrees: angleDegrees) } }
        let segments = straightHachureLines(rotated, gap: gap)
        return segments.map { (rotate($0.0, byDegrees: -angleDegrees), rotate($0.1, byDegrees: -angleDegrees)) }
    }

    private func straightHachureLines(_ polygons: [[Point]], gap: Double) -> [(Point, Point)] {
        var rings: [[Point]] = []
        for poly in polygons {
            var vertices = poly
            if let first = vertices.first, let last = vertices.last, !first.isApproximatelyEqual(to: last) {
                vertices.append(first)
            }
            if vertices.count > 2 { rings.append(vertices) }
        }
        guard !rings.isEmpty else { return [] }

        var minY = Double.infinity
        var maxY = -Double.infinity
        for ring in rings {
            for vertex in ring {
                minY = Swift.min(minY, vertex.y)
                maxY = Swift.max(maxY, vertex.y)
            }
        }

        var lines: [(Point, Point)] = []
        let step = Swift.max(gap, 0.1)
        var y = minY + step
        while y < maxY {
            var crossings: [Double] = []
            for ring in rings {
                for i in 1 ..< ring.count {
                    let p1 = ring[i - 1], p2 = ring[i]
                    if (p1.y < y && p2.y >= y) || (p2.y < y && p1.y >= y) {
                        let t = (y - p1.y) / (p2.y - p1.y)
                        crossings.append(p1.x + t * (p2.x - p1.x))
                    }
                }
            }
            crossings.sort()
            var i = 0
            while i + 1 < crossings.count {
                lines.append((Point(crossings[i], y), Point(crossings[i + 1], y)))
                i += 2
            }
            y += step
        }
        return lines
    }

    private func rotate(_ p: Point, byDegrees degrees: Double) -> Point {
        guard degrees != 0 else { return p }
        let rad = degrees * .pi / 180
        let c = cos(rad), s = sin(rad)
        return Point(p.x * c - p.y * s, p.x * s + p.y * c)
    }
}
