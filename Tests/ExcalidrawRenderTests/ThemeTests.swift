import CoreGraphics
import XCTest
@testable import ExcalidrawRender

final class ThemeTests: XCTestCase {
    private func rgb(_ c: CGColor) -> [CGFloat] { Array((c.components ?? []).prefix(3)) }

    func testLightThemeIsIdentity() {
        let color = CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        XCTAssertEqual(rgb(ThemeFilter.apply(color, theme: .light)), rgb(color))
    }

    func testDarkInvertsBlackAndWhite() {
        let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        let darkenedBlack = rgb(ThemeFilter.apply(black, theme: .dark))
        let darkenedWhite = rgb(ThemeFilter.apply(white, theme: .dark))
        // black -> ~white, white -> ~black.
        for v in darkenedBlack { XCTAssertEqual(v, 1, accuracy: 0.02) }
        for v in darkenedWhite { XCTAssertEqual(v, 0, accuracy: 0.02) }
    }

    func testDarkStaysInGamut() {
        let color = CGColor(red: 0.1, green: 0.45, blue: 0.76, alpha: 1)
        for v in rgb(ThemeFilter.apply(color, theme: .dark)) {
            XCTAssertGreaterThanOrEqual(v, 0)
            XCTAssertLessThanOrEqual(v, 1)
        }
    }

    func testDarkPreservesAlpha() {
        let color = CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.3)
        XCTAssertEqual(ThemeFilter.apply(color, theme: .dark).alpha, 0.3, accuracy: 0.001)
    }
}
