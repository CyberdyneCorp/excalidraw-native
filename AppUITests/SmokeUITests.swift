import XCTest

/// End-to-end editor flow on the simulator: launch, pick the rectangle tool,
/// draw on the canvas, export, then undo. Pencil/pressure paths are not
/// driveable from XCUITest and are covered by ExcalidrawEditor unit tests.
final class SmokeUITests: XCTestCase {
    func testDrawAndExportFlow() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.wait(for: .runningForeground, timeout: 10), true)

        XCTAssertTrue(app.buttons["tool-rectangle"].waitForExistence(timeout: 10))
        app.buttons["tool-rectangle"].tap()

        let canvas = app.otherElements["excalidraw-canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))

        // Draw a rectangle by dragging across the canvas.
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.6))
        start.press(forDuration: 0.1, thenDragTo: end)

        // Export the drawing and confirm.
        app.buttons["export"].tap()
        XCTAssertTrue(app.staticTexts["exported-confirmation"].waitForExistence(timeout: 5))

        // Undo should not crash.
        app.buttons["undo"].tap()
    }
}
