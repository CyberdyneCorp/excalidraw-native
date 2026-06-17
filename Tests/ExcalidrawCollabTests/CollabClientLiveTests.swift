import ExcalidrawModel
import Foundation
import XCTest
@testable import ExcalidrawCollab

/// Diagnostic: two real `CollabClient`s over a real relay (the same networking
/// path the iPad app uses), to verify the presence roster both ways. Skipped
/// unless `COLLAB_RELAY` points at a running relay.
final class CollabClientLiveTests: XCTestCase {
    private func waitUntil(_ cond: @escaping () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if cond() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return cond()
    }

    func testTwoClientsSeeEachOtherBothWays() throws {
        let env = ProcessInfo.processInfo.environment
        guard let relay = env["COLLAB_RELAY"], let url = URL(string: relay) else {
            throw XCTSkip("set COLLAB_RELAY to a running relay (web/scripts/relay)")
        }
        let room = "diag-\(UUID().uuidString.prefix(6))"

        // Peer A ("web") joins first and draws an element.
        final class Box { var peers: [Peer] = []; var scene = 0 }
        let aBox = Box(), bBox = Box()
        let a = CollabClient(
            url: url, peer: Peer(id: "web", name: "web", color: "#1"), room: room,
            handlers: .init(onPeersChanged: { aBox.peers = $0 })
        )
        a.connect()
        XCTAssertTrue(waitUntil { a.you != nil }, "A failed to join")

        var base = BaseProperties(id: "web-1")
        base.version = 1
        a.broadcastElements([ExcalidrawElement(base: base, kind: .rectangle)])

        // Peer B ("ipad") joins second — it must learn about A from room-state.
        let b = CollabClient(
            url: url, peer: Peer(id: "ipad", name: "ipad", color: "#2"), room: room,
            handlers: .init(
                onScene: { bBox.scene = $0.count },
                onPeersChanged: { bBox.peers = $0 }
            )
        )
        b.connect()
        XCTAssertTrue(waitUntil { b.you != nil }, "B failed to join")

        // B should receive A's element via the room snapshot…
        XCTAssertTrue(waitUntil { bBox.scene >= 1 }, "B did not receive A's element")
        // …and see A in its roster (this is the case the iPad screenshot showed as 0).
        XCTAssertTrue(
            waitUntil { bBox.peers.contains { $0.id == "web" } },
            "B roster missing A: \(bBox.peers.map(\.id))"
        )
        // A should see B (via peer-joined).
        XCTAssertTrue(
            waitUntil { aBox.peers.contains { $0.id == "ipad" } },
            "A roster missing B: \(aBox.peers.map(\.id))"
        )

        a.disconnect()
        b.disconnect()
    }

    func testEarlyJoinerLearnsLaterPeerViaPeerJoined() throws {
        let env = ProcessInfo.processInfo.environment
        guard let relay = env["COLLAB_RELAY"], let url = URL(string: relay) else {
            throw XCTSkip("set COLLAB_RELAY to a running relay (web/scripts/relay)")
        }
        let room = "diag2-\(UUID().uuidString.prefix(6))"
        final class Box { var peers: [Peer] = []; var elements = Set<String>() }
        let bBox = Box()

        // B ("ipad") joins the EMPTY room first.
        let b = CollabClient(
            url: url, peer: Peer(id: "ipad", name: "ipad", color: "#2"), room: room,
            handlers: .init(
                onScene: { for e in $0 {
                    bBox.elements.insert(e.id)
                } },
                onRemoteElements: { for e in $0 {
                    bBox.elements.insert(e.id)
                } },
                onPeersChanged: { bBox.peers = $0 }
            )
        )
        b.connect()
        XCTAssertTrue(waitUntil { b.you != nil }, "B failed to join")

        // A ("web") joins second and draws — B must learn A via peer-joined.
        let a = CollabClient(
            url: url, peer: Peer(id: "web", name: "web", color: "#1"), room: room, handlers: .init()
        )
        a.connect()
        XCTAssertTrue(waitUntil { a.you != nil }, "A failed to join")
        var base = BaseProperties(id: "web-1")
        base.version = 1
        a.broadcastElements([ExcalidrawElement(base: base, kind: .rectangle)])

        XCTAssertTrue(waitUntil { bBox.elements.contains("web-1") }, "B did not receive A's element")
        XCTAssertTrue(
            waitUntil { bBox.peers.contains { $0.id == "web" } },
            "B roster missing later peer A: \(bBox.peers.map(\.id))"
        )

        a.disconnect()
        b.disconnect()
    }
}
