import XCTest

/// Live cross-platform collaboration: this drives the **real app in the iOS
/// simulator** joining a room on a running relay, while a browser (Playwright)
/// joins the same room. Each side independently asserts it sees the other's
/// element — proving an iPad and a browser edit one scene together.
///
/// Skipped unless `COLLAB_RELAY` + `COLLAB_ROOM` are provided (via
/// `TEST_RUNNER_*` env), so the normal CI UI-test run is unaffected. Run it via
/// `web/scripts/collab-live.sh`, which starts the relay + the web peer.
final class CollabLiveUITests: XCTestCase {
    func testIPadAndBrowserShareOneRoom() throws {
        let env = ProcessInfo.processInfo.environment
        guard let relay = env["COLLAB_RELAY"], let room = env["COLLAB_ROOM"] else {
            throw XCTSkip("set COLLAB_RELAY / COLLAB_ROOM (see scripts/collab-live.sh)")
        }
        let name = env["COLLAB_NAME"] ?? "ipad"

        let app = XCUIApplication()
        app.launchArguments = [
            "-collabRelay", relay, "-collabRoom", room, "-collabName", name
        ]
        app.launch()
        XCTAssertEqual(app.wait(for: .runningForeground, timeout: 15), true)

        let canvas = app.otherElements["excalidraw-canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 15))
        let count = app.staticTexts["collab-element-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 15))

        // The browser peer drew one element; we receive it (room snapshot on
        // join, or a live element-update) → the shared count reaches 1.
        waitForCount(app, "collab-element-count", atLeast: 1, timeout: 60)

        // The browser peer must be in our roster too (presence both ways). Check
        // this *before* we draw: the browser stays connected until it sees our
        // element, so it is guaranteed present here.
        waitForCount(app, "collab-peer-count", atLeast: 1, timeout: 30)

        // Draw our own rectangle → count 2, broadcast to the browser.
        app.buttons["tool-rectangle"].tap()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35))
            .press(
                forDuration: 0.15,
                thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.62))
            )
        waitForCount(app, "collab-element-count", atLeast: 2, timeout: 30)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways
        shot.name = "ipad-collab-live"
        add(shot)

        // Give the browser a moment to receive our element before the relay tears down.
        sleep(2)
    }

    private func waitForCount(
        _ app: XCUIApplication, _ identifier: String, atLeast target: Int, timeout: TimeInterval
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        var last = ""
        while Date() < deadline {
            last = app.staticTexts[identifier].label
            if let value = Int(last), value >= target { return }
            usleep(250_000)
        }
        XCTFail("\(identifier) did not reach \(target) (last seen: \(last))")
    }
}
