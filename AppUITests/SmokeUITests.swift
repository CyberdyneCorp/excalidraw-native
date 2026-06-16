import XCTest

/// End-to-end editor flows on device/simulator. Pencil/pressure and the exact
/// rendering math are covered by unit tests; these drive the real UI to make
/// sure the tools, generators, and the layered/gesture rendering paths work
/// (and don't crash or garble) on real hardware.
final class SmokeUITests: XCTestCase {
    private var app: XCUIApplication!
    private var canvas: XCUIElement!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.wait(for: .runningForeground, timeout: 10), true)
        canvas = app.otherElements["excalidraw-canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
    }

    private func drag(_ from: CGVector, _ to: CGVector, duration: TimeInterval = 0.1) {
        canvas.coordinate(withNormalizedOffset: from)
            .press(forDuration: duration, thenDragTo: canvas.coordinate(withNormalizedOffset: to))
    }

    private func tap(_ tool: String) {
        let button = app.buttons[tool]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "missing \(tool)")
        button.tap()
    }

    func testDrawTextAndExportFlow() {
        tap("tool-rectangle")
        drag(CGVector(dx: 0.3, dy: 0.3), CGVector(dx: 0.6, dy: 0.55))

        tap("tool-freedraw")
        drag(CGVector(dx: 0.2, dy: 0.7), CGVector(dx: 0.5, dy: 0.8))

        tap("tool-text")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.42)).tap()
        let textField = app.textFields["text-editor"]
        if textField.waitForExistence(timeout: 5) {
            textField.tap(); textField.typeText("Hi")
            app.buttons["text-done"].tap()
        }

        app.buttons["export"].tap()
        XCTAssertTrue(app.staticTexts["exported-confirmation"].waitForExistence(timeout: 5))
    }

    func testStickyNoteTableAndChart() {
        // Sticky note: drop and label it.
        tap("tool-postit")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35)).tap()
        let noteText = app.textFields["text-editor"]
        if noteText.waitForExistence(timeout: 5) {
            noteText.tap(); noteText.typeText("Todo")
            app.buttons["text-done"].tap()
        }

        // Table: drop a grid.
        tap("tool-table")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.3)).tap()

        // Chart: open the sheet, enter values, insert.
        tap("chart")
        let values = app.textFields["chart-values"]
        if values.waitForExistence(timeout: 5) {
            values.tap(); values.typeText("4, 8, 15, 16, 23")
            app.buttons["chart-insert"].tap()
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testStrokeWidthAndColors() {
        // Draw a rectangle (it stays selected), then restyle it: stroke colour,
        // fill colour, and stroke width.
        tap("tool-rectangle")
        drag(CGVector(dx: 0.3, dy: 0.3), CGVector(dx: 0.6, dy: 0.55))

        tap("stroke-#e03131") // red stroke
        tap("bg-#a5d8ff") // blue fill

        // Bump the stroke width via the stepper's increment.
        let stepper = app.steppers["stroke-width"]
        if stepper.waitForExistence(timeout: 5) {
            let increment = stepper.buttons["Increment"]
            if increment.exists { increment.tap(); increment.tap() } else { stepper.tap() }
        }

        app.buttons["export"].tap()
        XCTAssertTrue(app.staticTexts["exported-confirmation"].waitForExistence(timeout: 5))
    }

    func testMovePanAndZoom() {
        // Draw a rectangle, then move it with the selection tool (exercises the
        // static/dynamic layered render path).
        tap("tool-rectangle")
        drag(CGVector(dx: 0.3, dy: 0.3), CGVector(dx: 0.55, dy: 0.5))
        tap("tool-selection")
        drag(CGVector(dx: 0.3, dy: 0.4), CGVector(dx: 0.5, dy: 0.6)) // grab the left edge and move

        // Pan/zoom the board (exercises the gesture-snapshot path).
        canvas.pinch(withScale: 1.8, velocity: 1.2) // zoom in
        canvas.pinch(withScale: 0.6, velocity: -1.2) // zoom out

        // Footer zoom controls.
        if app.buttons["zoom-in"].waitForExistence(timeout: 5) {
            app.buttons["zoom-in"].tap()
            app.buttons["zoom-out"].tap()
            app.buttons["zoom-fit"].tap()
        }
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(canvas.exists)
    }

    func testAddPointsToLine() {
        // Draw a line, enter point-edit (double-tap), then drag near its
        // midpoint to insert/move a point.
        tap("tool-line")
        drag(CGVector(dx: 0.25, dy: 0.4), CGVector(dx: 0.7, dy: 0.4))
        tap("tool-selection")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.475, dy: 0.4)).doubleTap()
        drag(CGVector(dx: 0.475, dy: 0.4), CGVector(dx: 0.475, dy: 0.6)) // pull the midpoint down
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(canvas.exists)
    }
}
