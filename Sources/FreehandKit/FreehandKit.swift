import ExcalidrawMath
import Foundation

/// One input sample for a freehand stroke.
public struct FreehandPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var pressure: Double

    public init(x: Double, y: Double, pressure: Double = 0.5) {
        self.x = x
        self.y = y
        self.pressure = pressure
    }
}

/// Stroke-shaping options (perfect-freehand). Defaults match Excalidraw's
/// freedraw tuning in `packages/element/src/shape.ts`.
public struct FreehandOptions: Sendable {
    public var size: Double = 16
    public var thinning: Double = 0.6
    public var smoothing: Double = 0.5
    public var streamline: Double = 0.5
    public var simulatePressure: Bool = true
    public var last: Bool = true

    public init() {}

    /// Excalidraw uses `size = strokeWidth * 4.25`.
    public init(strokeWidth: Double, simulatePressure: Bool) {
        size = strokeWidth * FreehandKit.sizeMultiplier
        self.simulatePressure = simulatePressure
    }
}

/// Pressure-aware freehand stroke outlines — a port of `perfect-freehand`.
///
/// Produces the filled outline polygon for a freedraw element from its input
/// points and per-point pressures: streamline the input, compute a per-point
/// radius from pressure (thinning + ease), offset perpendicular to the travel
/// direction, and join the two sides into a closed ribbon.
///
/// Faithful in form to perfect-freehand; exact numeric parity is not validated
/// (the library isn't available locally). Sharp-corner insets and rounded end
/// caps are simplified to flat caps.
public enum FreehandKit {
    /// Stroke size multiplier applied to `strokeWidth` (upstream freedraw).
    public static let sizeMultiplier = 4.25
    private static let rateOfPressureChange = 0.275

    /// The closed outline polygon for a freehand stroke.
    public static func strokeOutline(
        _ inputs: [FreehandPoint], options: FreehandOptions = FreehandOptions()
    ) -> [Point] {
        // A single tap renders as a filled dot.
        if inputs.count <= 1 {
            guard let p = inputs.first else { return [] }
            return circle(center: Point(p.x, p.y), radius: options.size / 2)
        }
        let points = strokePoints(inputs, options: options)
        return outline(points, options: options)
    }

    // MARK: Stroke points (streamline + direction + running length)

    struct StrokePoint {
        var point: Point
        var pressure: Double
        var vector: Vector
        var distance: Double
        var runningLength: Double
    }

    static func strokePoints(_ inputs: [FreehandPoint], options: FreehandOptions) -> [StrokePoint] {
        var pts = inputs
        guard let first = pts.first else { return [] }
        if pts.count == 1 {
            pts.append(FreehandPoint(x: first.x + 1, y: first.y + 1, pressure: first.pressure))
        }

        var result: [StrokePoint] = [
            StrokePoint(
                point: Point(first.x, first.y),
                pressure: first.pressure >= 0 ? first.pressure : 0.25,
                vector: Vector(1, 1), distance: 0, runningLength: 0
            ),
        ]
        var prevPoint = result[0].point
        var runningLength = 0.0
        var hasMinLength = false
        let maxIdx = pts.count - 1

        for i in 1...maxIdx {
            let raw = Point(pts[i].x, pts[i].y)
            let point = (options.last && i == maxIdx) ? raw : lerp(prevPoint, raw, 1 - options.streamline)
            if point.isApproximatelyEqual(to: prevPoint) { continue }
            let distance = point.distance(to: prevPoint)
            runningLength += distance
            if i < maxIdx, !hasMinLength {
                if runningLength < options.size { continue }
                hasMinLength = true
            }
            result.append(StrokePoint(
                point: point,
                pressure: pts[i].pressure >= 0 ? pts[i].pressure : 0.5,
                vector: Vector(from: prevPoint, origin: point).normalized(),
                distance: distance, runningLength: runningLength
            ))
            prevPoint = point
        }
        if result.count > 1 { result[0].vector = result[1].vector }
        return result
    }

    // MARK: Outline

    static func outline(_ points: [StrokePoint], options: FreehandOptions) -> [Point] {
        guard let first = points.first else { return [] }
        let size = options.size
        let totalLength = points.last?.runningLength ?? 0
        let minDistanceSq = pow(size * options.smoothing, 2)

        // A dot (no travel) renders as a filled circle.
        if points.count <= 1 || totalLength == 0 {
            return circle(center: first.point, radius: size / 2)
        }

        var left: [Point] = []
        var right: [Point] = []
        var pl = first.point
        var pr = first.point
        var prevPressure = first.pressure

        for i in 0..<points.count {
            let sp = points[i]
            if i < points.count - 1, totalLength - sp.runningLength < 3 { continue }

            var pressure = sp.pressure
            let radius: Double
            if options.thinning != 0 {
                if options.simulatePressure {
                    let sp2 = min(1, sp.distance / size)
                    let rp = min(1, 1 - sp2)
                    pressure = min(1, prevPressure + (rp - prevPressure) * (sp2 * rateOfPressureChange))
                }
                radius = size * ease(0.5 - options.thinning * (0.5 - pressure))
            } else {
                radius = size / 2
            }

            let nextVector = i < points.count - 1 ? points[i + 1].vector : sp.vector
            let nextDpr = i < points.count - 1 ? sp.vector.dot(nextVector) : 1
            let offsetDir = lerpVector(nextVector, sp.vector, nextDpr).normal()
            let offset = offsetDir.scaled(by: radius)

            let tl = Point(sp.point.x - offset.u, sp.point.y - offset.v)
            let tr = Point(sp.point.x + offset.u, sp.point.y + offset.v)
            if i <= 1 || pl.distanceSquared(to: tl) > minDistanceSq { left.append(tl); pl = tl }
            if i <= 1 || pr.distanceSquared(to: tr) > minDistanceSq { right.append(tr); pr = tr }
            prevPressure = pressure
        }

        // Closed ribbon: left side, then the right side reversed (flat caps).
        return left + right.reversed()
    }

    // MARK: Helpers

    static func ease(_ t: Double) -> Double { sin(max(0, min(1, t)) * .pi / 2) }

    static func lerp(_ a: Point, _ b: Point, _ t: Double) -> Point {
        Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
    }

    static func lerpVector(_ a: Vector, _ b: Vector, _ t: Double) -> Vector {
        Vector(a.u + (b.u - a.u) * t, a.v + (b.v - a.v) * t)
    }

    static func circle(center: Point, radius: Double, segments: Int = 16) -> [Point] {
        (0..<segments).map { i in
            let angle = 2 * Double.pi * Double(i) / Double(segments)
            return Point(center.x + radius * cos(angle), center.y + radius * sin(angle))
        }
    }
}
