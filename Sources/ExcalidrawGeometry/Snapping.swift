import ExcalidrawMath
import Foundation

/// The result of snapping a moving box against the grid and/or other elements:
/// an offset to apply plus the matched guide lines (for the overlay).
public struct SnapResult: Equatable, Sendable {
    public var offsetX: Double
    public var offsetY: Double
    /// Scene x-coordinates of vertical guide lines (matched edges/centres).
    public var verticalLines: [Double]
    /// Scene y-coordinates of horizontal guide lines.
    public var horizontalLines: [Double]

    public static let none = SnapResult(offsetX: 0, offsetY: 0, verticalLines: [], horizontalLines: [])
}

/// Grid and object snapping (`packages/excalidraw/snapping.ts`).
public enum Snapping {
    public static let defaultDistance = 8.0

    /// Snap a point to the nearest grid intersection.
    public static func snapToGrid(_ point: Point, gridSize: Double) -> Point {
        guard gridSize > 0 else { return point }
        return Point(
            (point.x / gridSize).rounded() * gridSize,
            (point.y / gridSize).rounded() * gridSize
        )
    }

    /// Snap `moving` to the edges/centres of `statics` within `threshold`,
    /// returning the offset that aligns them plus the matched guide lines.
    public static func snap(
        moving: BoundingBox, statics: [BoundingBox], threshold: Double
    ) -> SnapResult {
        let movingX = [moving.minX, (moving.minX + moving.maxX) / 2, moving.maxX]
        let movingY = [moving.minY, (moving.minY + moving.maxY) / 2, moving.maxY]
        let staticX = statics.flatMap { [$0.minX, ($0.minX + $0.maxX) / 2, $0.maxX] }
        let staticY = statics.flatMap { [$0.minY, ($0.minY + $0.maxY) / 2, $0.maxY] }

        let (offsetX, lineX) = bestSnap(moving: movingX, statics: staticX, threshold: threshold)
        let (offsetY, lineY) = bestSnap(moving: movingY, statics: staticY, threshold: threshold)

        return SnapResult(
            offsetX: offsetX, offsetY: offsetY,
            verticalLines: lineX.map { [$0] } ?? [],
            horizontalLines: lineY.map { [$0] } ?? []
        )
    }

    /// Gap (distribution) snapping: snap `moving` so it either sits centred in
    /// the gap between two neighbours, or repeats an existing gap between two
    /// adjacent neighbours. Only neighbours that overlap `moving` on the
    /// perpendicular axis are considered, mirroring Excalidraw's gap snaps.
    public static func gapSnap(
        moving: BoundingBox, statics: [BoundingBox], threshold: Double
    ) -> SnapResult {
        // X gaps: neighbours must overlap on Y.
        let xSpans = statics
            .filter { overlaps($0.minY, $0.maxY, moving.minY, moving.maxY) }
            .map { Span(lo: $0.minX, hi: $0.maxX) }
        let (offsetX, linesX) = gapSnap1D(
            movingLo: moving.minX,
            movingHi: moving.maxX,
            spans: xSpans,
            threshold: threshold
        )
        // Y gaps: neighbours must overlap on X.
        let ySpans = statics
            .filter { overlaps($0.minX, $0.maxX, moving.minX, moving.maxX) }
            .map { Span(lo: $0.minY, hi: $0.maxY) }
        let (offsetY, linesY) = gapSnap1D(
            movingLo: moving.minY,
            movingHi: moving.maxY,
            spans: ySpans,
            threshold: threshold
        )

        return SnapResult(offsetX: offsetX, offsetY: offsetY, verticalLines: linesX, horizontalLines: linesY)
    }

    private struct Span {
        var lo: Double
        var hi: Double
    }

    private static func overlaps(_ aLo: Double, _ aHi: Double, _ bLo: Double, _ bHi: Double) -> Bool {
        aLo <= bHi && bLo <= aHi
    }

    /// One-axis gap snapping over `spans` (the snap-axis intervals of the
    /// perpendicular-overlapping neighbours). Returns the best offset and the
    /// guide lines to show (empty when nothing snapped).
    private static func gapSnap1D(
        movingLo: Double, movingHi: Double, spans: [Span], threshold: Double
    ) -> (offset: Double, lines: [Double]) {
        let movingWidth = movingHi - movingLo
        let movingCenter = (movingLo + movingHi) / 2
        let sorted = spans.sorted { $0.lo < $1.lo }
        var best: (offset: Double, lines: [Double])?

        func consider(_ offset: Double, _ lines: [Double]) {
            guard abs(offset) <= threshold else { return }
            if best == nil || abs(offset) < abs(best!.offset) { best = (offset, lines) }
        }

        for i in 0 ..< sorted.count {
            for j in (i + 1) ..< sorted.count {
                let a = sorted[i], b = sorted[j]
                guard a.hi <= b.lo else { continue }
                let gap = b.lo - a.hi
                // Centre `moving` in the gap between a and b.
                if gap >= movingWidth {
                    consider((a.hi + b.lo) / 2 - movingCenter, [a.hi, b.lo])
                }
                // Repeat the gap to the right of b, or to the left of a.
                consider((b.hi + gap) - movingLo, [b.hi, b.hi + gap])
                consider((a.lo - gap) - movingHi, [a.lo - gap, a.lo])
            }
        }
        return (best?.offset ?? 0, best?.lines ?? [])
    }

    /// Find the smallest-magnitude offset that brings any moving candidate within
    /// `threshold` of any static candidate. Returns the offset and the matched
    /// static line, or `(0, nil)` if nothing snaps.
    private static func bestSnap(
        moving: [Double], statics: [Double], threshold: Double
    ) -> (offset: Double, line: Double?) {
        var best: (offset: Double, line: Double)?
        for m in moving {
            for s in statics {
                let delta = s - m
                if abs(delta) <= threshold, best == nil || abs(delta) < abs(best!.offset) {
                    best = (delta, s)
                }
            }
        }
        return (best?.offset ?? 0, best?.line)
    }
}
