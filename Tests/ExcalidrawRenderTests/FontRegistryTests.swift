import ExcalidrawModel
import XCTest
@testable import ExcalidrawRender

final class FontRegistryTests: XCTestCase {
    func testFallsBackToSystemWhenNoBundledFont() {
        // No Excalidraw fonts are bundled in the test host, so handwriting
        // families fall back to the system handwriting face.
        XCTAssertEqual(FontRegistry.fontName(for: FontFamily.excalifont), "Bradley Hand")
        XCTAssertEqual(FontRegistry.fontName(for: FontFamily.comicShanns), "Menlo")
    }

    func testSansFamiliesMapToHelvetica() {
        XCTAssertEqual(FontRegistry.fontName(for: FontFamily.helvetica), "Helvetica")
        XCTAssertEqual(FontRegistry.fontName(for: FontFamily.liberationSans), "Helvetica")
    }

    func testUnknownFamilyHasAHandwritingFallback() {
        XCTAssertEqual(FontRegistry.fontName(for: 999), "Bradley Hand")
    }

    func testRegisterIsIdempotent() {
        FontRegistry.registerBundledFonts()
        FontRegistry.registerBundledFonts() // must not crash or duplicate-register
        XCTAssertEqual(FontRegistry.fontName(for: FontFamily.helvetica), "Helvetica")
    }

    func testTextLayoutUsesTheRegistry() {
        // TextLayout routes through the registry; the default (Excalifont) maps
        // to the handwriting fallback here.
        XCTAssertEqual(TextLayout.fontName(for: FontFamily.default), "Bradley Hand")
    }
}
