import ExcalidrawMath
import Foundation

/// Ear-clipping polygon triangulation. Handles simple (possibly concave)
/// polygons; degenerate or self-intersecting input degrades to a centroid fan
/// rather than failing, which is acceptable for hand-drawn rough fills where
/// exact coverage of a near-simple polygon is imperceptible.
enum PolygonTriangulator {
    /// Triangulate `polygon` (no repeated closing vertex) into a flat triangle
    /// list. Returns `[]` for fewer than three vertices.
    static func earClip(_ polygon: [Point]) -> [Point] {
        let n = polygon.count
        guard n >= 3 else { return [] }
        if n == 3 { return polygon }

        // Work on an index ring so vertices can be clipped in O(1).
        var indices = Array(0 ..< n)
        let ccw = signedArea(polygon) > 0
        var triangles: [Point] = []
        triangles.reserveCapacity((n - 2) * 3)

        var guardCount = 0
        let maxIterations = n * n
        while indices.count > 3, guardCount < maxIterations {
            guardCount += 1
            var clipped = false
            let count = indices.count
            for i in 0 ..< count {
                let prev = indices[(i + count - 1) % count]
                let curr = indices[i]
                let next = indices[(i + 1) % count]
                let a = polygon[prev], b = polygon[curr], c = polygon[next]
                if isEar(a, b, c, polygon: polygon, ring: indices, ccw: ccw) {
                    triangles.append(contentsOf: [a, b, c])
                    indices.remove(at: i)
                    clipped = true
                    break
                }
            }
            // No ear found (numerical issue / non-simple polygon): fall back.
            if !clipped { return centroidFan(polygon) }
        }

        if indices.count == 3 {
            triangles.append(contentsOf: indices.map { polygon[$0] })
        }
        return triangles
    }

    private static func isEar(
        _ a: Point, _ b: Point, _ c: Point, polygon: [Point], ring: [Int], ccw: Bool
    ) -> Bool {
        // Convex test relative to the polygon winding.
        let cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        if ccw, cross <= 0 { return false }
        if !ccw, cross >= 0 { return false }
        // No other vertex may lie inside triangle abc.
        for index in ring {
            let p = polygon[index]
            if p == a || p == b || p == c { continue }
            if pointInTriangle(p, a, b, c) { return false }
        }
        return true
    }

    private static func pointInTriangle(_ p: Point, _ a: Point, _ b: Point, _ c: Point) -> Bool {
        let d1 = sign(p, a, b)
        let d2 = sign(p, b, c)
        let d3 = sign(p, c, a)
        let hasNeg = d1 < 0 || d2 < 0 || d3 < 0
        let hasPos = d1 > 0 || d2 > 0 || d3 > 0
        return !(hasNeg && hasPos)
    }

    private static func sign(_ p1: Point, _ p2: Point, _ p3: Point) -> Double {
        (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
    }

    private static func signedArea(_ polygon: [Point]) -> Double {
        var area = 0.0
        for i in 0 ..< polygon.count {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            area += a.x * b.y - b.x * a.y
        }
        return area / 2
    }

    /// Fan from the centroid: covers convex polygons exactly and gives a
    /// reasonable approximation for mildly concave ones when ear clipping bails.
    private static func centroidFan(_ polygon: [Point]) -> [Point] {
        let n = polygon.count
        var cx = 0.0, cy = 0.0
        for p in polygon {
            cx += p.x; cy += p.y
        }
        let centroid = Point(cx / Double(n), cy / Double(n))
        var triangles: [Point] = []
        triangles.reserveCapacity(n * 3)
        for i in 0 ..< n {
            triangles.append(contentsOf: [centroid, polygon[i], polygon[(i + 1) % n]])
        }
        return triangles
    }
}
