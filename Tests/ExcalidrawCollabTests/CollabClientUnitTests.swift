import ExcalidrawModel
import Foundation
import XCTest
@testable import ExcalidrawCollab

/// Socket-free unit coverage of `CollabClient`'s inbound dispatch + outbound
/// helpers, driven through `handleRaw` (no real connection needed).
final class CollabClientUnitTests: XCTestCase {
    private final class Sink {
        var scene: [ExcalidrawElement] = []
        var remote: [ExcalidrawElement] = []
        var rosters: [[Peer]] = []
        var cursors: [(String, PointerPos?)] = []
    }

    private func makeClient(_ sink: Sink, me: String = "me") throws -> CollabClient {
        let url = try XCTUnwrap(URL(string: "ws://127.0.0.1:1"))
        return CollabClient(
            url: url, peer: Peer(id: me, name: me, color: "#0"), room: "r",
            handlers: .init(
                onScene: { sink.scene = $0 },
                onRemoteElements: { sink.remote = $0 },
                onPeersChanged: { sink.rosters.append($0) },
                onCursor: { sink.cursors.append(($0, $1)) }
            )
        )
    }

    private func rect(_ id: String) -> ExcalidrawElement {
        ExcalidrawElement(base: BaseProperties(id: id), kind: .rectangle)
    }

    private func feed(_ client: CollabClient, _ message: CollabMessage) throws {
        try client.handleRaw(CollabCodec.encode(message))
    }

    func testRoomStateRecordsIdRosterAndScene() throws {
        let sink = Sink()
        let client = try makeClient(sink)
        let other = Peer(id: "web", name: "web", color: "#1")
        try feed(client, .roomState(
            protocolVersion: 1, you: "me", peers: [other, Peer(id: "me", name: "me", color: "#0")],
            elements: [rect("a")]
        ))
        XCTAssertEqual(client.you, "me")
        XCTAssertEqual(client.peers.keys.sorted(), ["web"]) // self excluded
        XCTAssertEqual(sink.scene.map(\.id), ["a"])
        XCTAssertEqual(sink.rosters.last?.map(\.id), ["web"])
    }

    func testPeerJoinedAndLeft() throws {
        let sink = Sink()
        let client = try makeClient(sink)
        try feed(client, .peerJoined(peer: Peer(id: "web", name: "web", color: "#1")))
        XCTAssertTrue(client.peers.keys.contains("web"))
        try feed(client, .peerLeft(peerId: "web"))
        XCTAssertFalse(client.peers.keys.contains("web"))
    }

    func testPresenceAndPointerDeliverCursors() throws {
        let sink = Sink()
        let client = try makeClient(sink)
        try feed(client, .presence(
            peerId: "web", presence: Presence(pointer: PointerPos(x: 1, y: 2), selectedIds: [], tool: "selection")
        ))
        try feed(client, .pointer(peerId: "web", pointer: PointerPos(x: 3, y: 4)))
        XCTAssertEqual(sink.cursors.count, 2)
        XCTAssertEqual(sink.cursors.last?.1, PointerPos(x: 3, y: 4))
    }

    func testElementUpdatesAndSnapshot() throws {
        let sink = Sink()
        let client = try makeClient(sink)
        try feed(client, .elementUpdates(elements: [rect("x")]))
        XCTAssertEqual(sink.remote.map(\.id), ["x"])
        try feed(client, .sceneSnapshot(elements: [rect("y"), rect("z")]))
        XCTAssertEqual(sink.scene.map(\.id), ["y", "z"])
    }

    func testOutboundHelpersAreSafeWithoutAConnection() throws {
        let sink = Sink()
        let client = try makeClient(sink)
        try feed(client, .roomState(protocolVersion: 1, you: "me", peers: [], elements: []))
        // No socket attached: these must be no-ops, not crashes.
        client.broadcastElements([rect("e")])
        client.broadcastElements([]) // empty batch ignored
        client.sendPresence(Presence(pointer: nil, selectedIds: [], tool: "selection"))
        client.sendPointer(PointerPos(x: 0, y: 0))
        client.disconnect()
    }

    func testMalformedFrameIsIgnored() throws {
        let sink = Sink()
        let client = try makeClient(sink)
        client.handleRaw("{not valid json")
        client.handleRaw(#"{"type":"explode"}"#)
        XCTAssertTrue(sink.rosters.isEmpty)
        XCTAssertTrue(sink.scene.isEmpty)
    }
}
