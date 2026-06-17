import ExcalidrawCollab
import ExcalidrawModel
import Foundation
import XCTest
@testable import ExcalidrawUI

/// Socket-free coverage of the model's collab launch wiring + apply/broadcast
/// paths (the live-relay behaviour is covered by EditorModelCollabLiveTests).
@MainActor
final class EditorModelCollabUnitTests: XCTestCase {
    func testJoinFromLaunchArgumentsStartsCollabAndNamespacesIds() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "collab-test-\(UUID().uuidString)"))
        defaults.set("ws://127.0.0.1:1", forKey: "collabRelay")
        defaults.set("room-1", forKey: "collabRoom")
        defaults.set("ipad", forKey: "collabName")

        let model = EditorModel()
        model.joinCollabFromLaunchArguments(defaults)
        XCTAssertNotNil(model.collab)
        XCTAssertTrue(model.controller.idPrefix.hasPrefix("ipad-"))

        model.stopCollab()
        XCTAssertNil(model.collab)
    }

    func testJoinFromLaunchArgumentsNoOpWithoutConfig() throws {
        let model = EditorModel()
        try model.joinCollabFromLaunchArguments(XCTUnwrap(UserDefaults(suiteName: "empty-\(UUID().uuidString)")))
        XCTAssertNil(model.collab)
    }

    func testApplyRemoteSceneMergesAndApplyRemoteElementsReconciles() {
        let model = EditorModel()
        var sent: [ExcalidrawElement] = []
        model.attachCollabSink(idPrefix: "me-") { sent.append(contentsOf: $0) }

        func rect(_ id: String, _ version: Int, _ width: Double = 10) -> ExcalidrawElement {
            var base = BaseProperties(id: id)
            base.version = version
            base.width = width
            return ExcalidrawElement(base: base, kind: .rectangle)
        }

        // A room snapshot merges in (and is not re-broadcast as it is already known).
        model.applyRemoteScene([rect("peer-1", 1)])
        XCTAssertNotNil(model.controller.scene.element(id: "peer-1"))

        // A higher-versioned remote element wins reconciliation.
        model.applyRemoteElements([rect("peer-1", 2, 99)])
        XCTAssertEqual(model.controller.scene.element(id: "peer-1")?.base.width, 99)
        // Remote edits do not pollute the local undo stack.
        XCTAssertFalse(model.controller.canUndo)
    }
}
