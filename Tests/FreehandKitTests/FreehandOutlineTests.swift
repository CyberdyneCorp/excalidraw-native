import ExcalidrawMath
import XCTest
@testable import FreehandKit

final class FreehandOutlineTests: XCTestCase {
    private func line(_ count: Int, pressure: Double, dx: Double = 10) -> [FreehandPoint] {
        (0..<count).map { FreehandPoint(x: Double($0) * dx, y: 0, pressure: pressure) }
    }

    private func bounds(_ pts: [Point]) -> (minX: Double, maxX: Double, minY: Double, maxY: Double) {
        (pts.map(\.x).min() ?? 0, pts.map(\.x).max() ?? 0, pts.map(\.y).min() ?? 0, pts.map(\.y).max() ?? 0)
    }

    func testEmptyInput() {
        XCTAssertTrue(FreehandKit.strokeOutline([]).isEmpty)
    }

    func testSinglePointIsCircle() {
        let outline = FreehandKit.strokeOutline([FreehandPoint(x: 50, y: 50)])
        XCTAssertEqual(outline.count, 16) // circle segments
        let b = bounds(outline)
        XCTAssertEqual((b.minX + b.maxX) / 2, 50, accuracy: 0.5)
    }

    func testDeterministic() {
        let pts = line(8, pressure: 0.5)
        XCTAssertEqual(FreehandKit.strokeOutline(pts), FreehandKit.strokeOutline(pts))
    }

    func testStraightStrokeIsRibbonAroundPath() {
        var opts = FreehandOptions(); opts.simulatePressure = false
        let outline = FreehandKit.strokeOutline(line(10, pressure: 0.5), options: opts)
        XCTAssertGreaterThan(outline.count, 4)
        let b = bounds(outline)
        // Ribbon spans the x extent of the path and has thickness in y.
        XCTAssertGreaterThan(b.maxX - b.minX, 50)
        XCTAssertGreaterThan(b.maxY - b.minY, 2)
    }

    func testHigherPressureIsWider() {
        var opts = FreehandOptions(); opts.simulatePressure = false
        let thin = FreehandKit.strokeOutline(line(10, pressure: 0.2), options: opts)
        let thick = FreehandKit.strokeOutline(line(10, pressure: 0.9), options: opts)
        func thickness(_ pts: [Point]) -> Double { let b = bounds(pts); return b.maxY - b.minY }
        XCTAssertGreaterThan(thickness(thick), thickness(thin))
    }

    func testStrokePointsStreamlineReducesPoints() {
        // With streamline, the stroke points are smoothed; running length grows.
        let sps = FreehandKit.strokePoints(line(20, pressure: 0.5), options: FreehandOptions())
        XCTAssertGreaterThan(sps.count, 1)
        XCTAssertGreaterThan(sps.last!.runningLength, 0)
        // Running length is monotonic.
        for i in 1..<sps.count {
            XCTAssertGreaterThanOrEqual(sps[i].runningLength, sps[i - 1].runningLength)
        }
    }

    func testEasingClampsRange() {
        XCTAssertEqual(FreehandKit.ease(0), 0, accuracy: 1e-9)
        XCTAssertEqual(FreehandKit.ease(1), 1, accuracy: 1e-9)
        XCTAssertEqual(FreehandKit.ease(-5), 0, accuracy: 1e-9) // clamped
    }
}
