import ExcalidrawModel
import Foundation

/// The iOS/macOS collaboration client: a `URLSessionWebSocketTask` that speaks
/// the same `CollabMessage` wire format as the web client, so an iPad and a
/// browser share one room. Joins on connect, mirrors local edits as
/// `element-updates`, and surfaces remote edits/presence through `Handlers`
/// (the caller reconciles with ``Reconcile`` and applies to its scene).
/// (parity: the TypeScript `CollabSession`.)
public final class CollabClient {
    /// Callbacks for inbound room events. Called on an arbitrary queue.
    public struct Handlers {
        public var onScene: ([ExcalidrawElement]) -> Void
        public var onRemoteElements: ([ExcalidrawElement]) -> Void
        public var onPeersChanged: ([Peer]) -> Void
        public var onCursor: (_ peerId: String, _ pointer: PointerPos?) -> Void

        public init(
            onScene: @escaping ([ExcalidrawElement]) -> Void = { _ in },
            onRemoteElements: @escaping ([ExcalidrawElement]) -> Void = { _ in },
            onPeersChanged: @escaping ([Peer]) -> Void = { _ in },
            onCursor: @escaping (String, PointerPos?) -> Void = { _, _ in }
        ) {
            self.onScene = onScene
            self.onRemoteElements = onRemoteElements
            self.onPeersChanged = onPeersChanged
            self.onCursor = onCursor
        }
    }

    private let url: URL
    private let peer: Peer
    private let room: String
    private let handlers: Handlers
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var intentionalClose = false
    private var reconnectAttempt = 0
    /// Cap on the exponential reconnect backoff, in seconds.
    public var maxReconnectDelay: Double = 10

    /// The id the relay assigned this client (set once `room-state` arrives).
    public private(set) var you: String?
    /// The current peer roster (excluding self).
    public private(set) var peers: [String: Peer] = [:]

    public init(
        url: URL, peer: Peer, room: String, handlers: Handlers, session: URLSession = .shared
    ) {
        self.url = url
        self.peer = peer
        self.room = room
        self.handlers = handlers
        self.session = session
    }

    /// Open the socket, join the room, and start receiving. Auto-reconnects with
    /// exponential backoff if the connection drops (the relay re-sends
    /// `room-state` on rejoin, so the scene resyncs); `disconnect()` stops it.
    public func connect() {
        intentionalClose = false
        openSocket()
    }

    private func openSocket() {
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        send(.join(protocolVersion: protocolVersion, room: room, peer: peer))
        receiveNext()
    }

    /// Leave the room and close the socket (no reconnect).
    public func disconnect() {
        intentionalClose = true
        if let you { send(.leave(peerId: you)) }
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func scheduleReconnect() {
        guard !intentionalClose else { return }
        reconnectAttempt += 1
        let delay = min(maxReconnectDelay, 0.25 * pow(2.0, Double(reconnectAttempt - 1)))
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.intentionalClose else { return }
            openSocket()
        }
    }

    // MARK: Outbound

    public func broadcastElements(_ elements: [ExcalidrawElement]) {
        guard !elements.isEmpty else { return }
        send(.elementUpdates(elements: elements))
    }

    public func sendPresence(_ presence: Presence) {
        guard let you else { return }
        send(.presence(peerId: you, presence: presence))
    }

    public func sendPointer(_ pointer: PointerPos) {
        guard let you else { return }
        send(.pointer(peerId: you, pointer: pointer))
    }

    // MARK: Internals

    /// Encode + send a message (exposed for tests / advanced use).
    public func send(_ message: CollabMessage) {
        guard let json = try? CollabCodec.encode(message) else { return }
        task?.send(.string(json)) { _ in }
    }

    private func receiveNext() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(message):
                reconnectAttempt = 0
                if case let .string(text) = message { handleRaw(text) }
                receiveNext()
            case .failure:
                scheduleReconnect() // dropped — redial with backoff and rejoin
            }
        }
    }

    /// Decode and dispatch one inbound frame (also the unit-test entry point).
    public func handleRaw(_ text: String) {
        guard let message = try? CollabCodec.decode(text) else { return }
        handle(message)
    }

    private func handle(_ message: CollabMessage) {
        switch message {
        case let .roomState(_, you, peers, elements):
            self.you = you
            self.peers = Dictionary(
                uniqueKeysWithValues: peers.filter { $0.id != you }.map { ($0.id, $0) }
            )
            handlers.onScene(elements)
            handlers.onPeersChanged(Array(self.peers.values))
        case let .peerJoined(peer):
            peers[peer.id] = peer
            handlers.onPeersChanged(Array(peers.values))
        case let .peerLeft(peerId):
            peers[peerId] = nil
            handlers.onPeersChanged(Array(peers.values))
        case let .presence(peerId, presence):
            handlers.onCursor(peerId, presence.pointer)
        case let .pointer(peerId, pointer):
            handlers.onCursor(peerId, pointer)
        case let .elementUpdates(elements):
            handlers.onRemoteElements(elements)
        case let .sceneSnapshot(elements):
            handlers.onScene(elements)
        default:
            break // join/leave/ping/ack are not inbound to a client
        }
    }
}
