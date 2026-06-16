import XCTest

/// End-to-end editor flow on the simulator: draw a shape, freedraw, place text,
/// then export. Pencil/pressure and multi-touch pan/zoom are covered by the
/// ExcalidrawEditor unit tests.
final class SmokeUITests: XCTestCase {
    func testDrawTextAndExportFlow() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.wait(for: .runningForeground, timeout: 10), true)

        let canvas = app.otherElements["excalidraw-canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))

        // Draw a rectangle.
        XCTAssertTrue(app.buttons["tool-rectangle"].waitForExistence(timeout: 10))
        app.buttons["tool-rectangle"].tap()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.55)))

        // Freedraw a scribble.
        app.buttons["tool-freedraw"].tap()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))

        // Place text.
        app.buttons["tool-text"].tap()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.4)).tap()
        let textField = app.textFields["text-editor"]
        if textField.waitForExistence(timeout: 5) {
            textField.tap()
            textField.typeText("Hi")
            app.buttons["text-done"].tap()
        }

        // Footer controls: zoom and dark mode.
        if app.buttons["zoom-in"].waitForExistence(timeout: 5) {
            app.buttons["zoom-in"].tap()
            app.buttons["theme-toggle"].tap()
            app.buttons["zoom-fit"].tap()
        }

        // Export and confirm.
        app.buttons["export"].tap()
        XCTAssertTrue(app.staticTexts["exported-confirmation"].waitForExistence(timeout: 5))
    }
}
