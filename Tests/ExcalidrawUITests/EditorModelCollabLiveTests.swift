import ExcalidrawCollab
import ExcalidrawModel
import Foundation
import XCTest
@testable import ExcalidrawUI

/// Diagnostic at the app layer: a real `EditorModel` joining a real relay where
/// another peer is already present, asserting the model's `remotePeers` roster
/// populates (the case the live iPad UI showed as 0). Skipped unless
/// `COLLAB_RELAY` points at a running relay.
@MainActor
final class EditorModelCollabLiveTests: XCTestCase {
    private func waitUntil(_ cond: @escaping () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if cond() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return cond()
    }

    func testModelRosterPopulatesWhenAPeerIsPresent() throws {
        let env = ProcessInfo.processInfo.environment
        guard let relay = env["COLLAB_RELAY"], let url = URL(string: relay) else {
            throw XCTSkip("set COLLAB_RELAY to a running relay")
        }
        let room = "model-\(UUID().uuidString.prefix(6))"

        // A "web" peer joins first and draws.
        let web = CollabClient(
            url: url, peer: Peer(id: "web", name: "web", color: "#1"), room: room, handlers: .init()
        )
        web.connect()
        XCTAssertTrue(waitUntil { web.you != nil }, "web failed to join")
        var base = BaseProperties(id: "web-1")
        base.version = 1
        web.broadcastElements([ExcalidrawElement(base: base, kind: .rectangle)])

        // The iPad's real app object joins the same room.
        let model = EditorModel()
        model.startCollab(url: url, peer: Peer(id: "ipad", name: "ipad", color: "#2"), room: room)

        XCTAssertTrue(
            waitUntil { model.controller.scene.element(id: "web-1") != nil },
            "model did not receive the peer's element"
        )
        XCTAssertTrue(
            waitUntil { !model.remotePeers.isEmpty },
            "model.remotePeers stayed empty (roster bug): \(model.remotePeers.map(\.id))"
        )

        model.stopCollab()
        web.disconnect()
    }

    func testModelRosterPopulatesWhenItJoinsFirst() throws {
        let env = ProcessInfo.processInfo.environment
        guard let relay = env["COLLAB_RELAY"], let url = URL(string: relay) else {
            throw XCTSkip("set COLLAB_RELAY to a running relay")
        }
        let room = "model2-\(UUID().uuidString.prefix(6))"

        // The iPad's real app object joins the EMPTY room first.
        let model = EditorModel()
        model.startCollab(url: url, peer: Peer(id: "ipad", name: "ipad", color: "#2"), room: room)
        XCTAssertTrue(waitUntil { model.collab?.you != nil }, "model failed to join")

        // A "web" peer joins second and draws — the model must learn it via peer-joined.
        let web = CollabClient(
            url: url, peer: Peer(id: "web", name: "web", color: "#1"), room: room, handlers: .init()
        )
        web.connect()
        XCTAssertTrue(waitUntil { web.you != nil }, "web failed to join")
        var base = BaseProperties(id: "web-1")
        base.version = 1
        web.broadcastElements([ExcalidrawElement(base: base, kind: .rectangle)])

        XCTAssertTrue(
            waitUntil { model.controller.scene.element(id: "web-1") != nil },
            "model did not receive the later peer's element"
        )
        XCTAssertTrue(
            waitUntil { !model.remotePeers.isEmpty },
            "model.remotePeers stayed empty for a later peer: \(model.remotePeers.map(\.id))"
        )

        model.stopCollab()
        web.disconnect()
    }
}
