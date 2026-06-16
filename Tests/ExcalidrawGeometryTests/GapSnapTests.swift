import ExcalidrawMath
import XCTest
@testable import ExcalidrawGeometry

final class GapSnapTests: XCTestCase {
    private func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> BoundingBox {
        BoundingBox(minX: x, minY: y, maxX: x + w, maxY: y + h)
    }

    func testCentersBetweenTwoNeighbours() {
        // A: x 0..20, B: x 80..100, both span y 0..20. The 20-wide moving box
        // centred in the inner gap (20..80, centre 50) sits at x 40..60.
        let a = box(0, 0, 20, 20)
        let b = box(80, 0, 20, 20)
        // Currently at x 43..63 (centre 53) → snap left by 3 to centre 50.
        let moving = box(43, 0, 20, 20)
        let result = Snapping.gapSnap(moving: moving, statics: [a, b], threshold: 8)
        XCTAssertEqual(result.offsetX, -3, accuracy: 1e-9)
        XCTAssertEqual(result.verticalLines, [20, 80])
        XCTAssertEqual(result.offsetY, 0)
    }

    func testRepeatsGapToTheRight() {
        // A: 0..20, B: 40..60 → gap 20. Repeating to the right of B puts the
        // moving box's left edge at 80. Currently at 83 → snap by -3.
        let a = box(0, 0, 20, 20)
        let b = box(40, 0, 20, 20)
        let moving = box(83, 0, 20, 20)
        let result = Snapping.gapSnap(moving: moving, statics: [a, b], threshold: 8)
        XCTAssertEqual(result.offsetX, -3, accuracy: 1e-9)
        XCTAssertFalse(result.verticalLines.isEmpty)
    }

    func testNoGapSnapWithoutPerpendicularOverlap() {
        // Neighbours sit on a different row (no Y overlap) → no X gap snap.
        let a = box(0, 200, 20, 20)
        let b = box(80, 200, 20, 20)
        let moving = box(43, 0, 20, 20)
        let result = Snapping.gapSnap(moving: moving, statics: [a, b], threshold: 8)
        XCTAssertEqual(result.offsetX, 0)
        XCTAssertTrue(result.verticalLines.isEmpty)
    }

    func testNoGapSnapBeyondThreshold() {
        let a = box(0, 0, 20, 20)
        let b = box(80, 0, 20, 20)
        let moving = box(70, 0, 20, 20) // centre 80, far from target 50
        let result = Snapping.gapSnap(moving: moving, statics: [a, b], threshold: 8)
        XCTAssertEqual(result.offsetX, 0)
        XCTAssertTrue(result.verticalLines.isEmpty)
    }

    func testVerticalGapCentering() {
        // Stacked neighbours overlapping on X → centre the moving box vertically.
        let top = box(0, 0, 20, 20)
        let bottom = box(0, 80, 20, 20)
        let moving = box(0, 44, 20, 20) // centre 54 → snap up 4 to centre 50
        let result = Snapping.gapSnap(moving: moving, statics: [top, bottom], threshold: 8)
        XCTAssertEqual(result.offsetY, -4, accuracy: 1e-9)
        XCTAssertEqual(result.horizontalLines, [20, 80])
    }
}
