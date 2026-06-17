import ExcalidrawModel
import Foundation

/// Wire protocol version (must match `@xs/protocol`'s `PROTOCOL_VERSION`).
public let protocolVersion = 1

/// A collaborator's stable identity (cursor + roster entry).
public struct Peer: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var color: String

    public init(id: String, name: String, color: String) {
        self.id = id
        self.name = name
        self.color = color
    }
}

/// A live pointer position in scene coordinates.
public struct PointerPos: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A peer's broadcast presence: cursor, selection, active tool.
public struct Presence: Equatable, Sendable, Codable {
    public var pointer: PointerPos?
    public var selectedIds: [String]
    public var tool: String

    public init(pointer: PointerPos?, selectedIds: [String], tool: String) {
        self.pointer = pointer
        self.selectedIds = selectedIds
        self.tool = tool
    }

    enum CodingKeys: String, CodingKey { case pointer, selectedIds, tool }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pointer = try c.decodeIfPresent(PointerPos.self, forKey: .pointer)
        selectedIds = try c.decode([String].self, forKey: .selectedIds)
        tool = try c.decode(String.self, forKey: .tool)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pointer, forKey: .pointer) // emit `null` (not omit) to match the TS schema
        try c.encode(selectedIds, forKey: .selectedIds)
        try c.encode(tool, forKey: .tool)
    }
}

/// The collaboration messages, discriminated by a string `type` tag. The wire
/// format is byte-identical to the TypeScript `@xs/protocol` `Message` union.
public enum CollabMessage: Equatable, Sendable {
    case join(protocolVersion: Int, room: String, peer: Peer)
    case leave(peerId: String)
    case roomState(protocolVersion: Int, you: String, peers: [Peer], elements: [ExcalidrawElement])
    case peerJoined(peer: Peer)
    case peerLeft(peerId: String)
    case presence(peerId: String, presence: Presence)
    case pointer(peerId: String, pointer: PointerPos)
    case elementUpdates(elements: [ExcalidrawElement])
    case sceneSnapshot(elements: [ExcalidrawElement])
    case ping(t: Int)
    case ack(t: Int)
}

extension CollabMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case type, peer, peers, room, you, peerId, presence, pointer, elements, t
        case proto = "protocol"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "join":
            self = try .join(
                protocolVersion: c.decode(Int.self, forKey: .proto),
                room: c.decode(String.self, forKey: .room),
                peer: c.decode(Peer.self, forKey: .peer)
            )
        case "leave":
            self = try .leave(peerId: c.decode(String.self, forKey: .peerId))
        case "room-state":
            self = try .roomState(
                protocolVersion: c.decode(Int.self, forKey: .proto),
                you: c.decode(String.self, forKey: .you),
                peers: c.decode([Peer].self, forKey: .peers),
                elements: c.decode([ExcalidrawElement].self, forKey: .elements)
            )
        case "peer-joined":
            self = try .peerJoined(peer: c.decode(Peer.self, forKey: .peer))
        case "peer-left":
            self = try .peerLeft(peerId: c.decode(String.self, forKey: .peerId))
        case "presence":
            self = try .presence(
                peerId: c.decode(String.self, forKey: .peerId),
                presence: c.decode(Presence.self, forKey: .presence)
            )
        case "pointer":
            self = try .pointer(
                peerId: c.decode(String.self, forKey: .peerId),
                pointer: c.decode(PointerPos.self, forKey: .pointer)
            )
        case "element-updates":
            self = try .elementUpdates(elements: c.decode([ExcalidrawElement].self, forKey: .elements))
        case "scene-snapshot":
            self = try .sceneSnapshot(elements: c.decode([ExcalidrawElement].self, forKey: .elements))
        case "ping":
            self = try .ping(t: c.decode(Int.self, forKey: .t))
        case "ack":
            self = try .ack(t: c.decode(Int.self, forKey: .t))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c, debugDescription: "unknown message type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .join(proto, room, peer):
            try c.encode("join", forKey: .type)
            try c.encode(proto, forKey: .proto)
            try c.encode(room, forKey: .room)
            try c.encode(peer, forKey: .peer)
        case let .leave(peerId):
            try c.encode("leave", forKey: .type)
            try c.encode(peerId, forKey: .peerId)
        case let .roomState(proto, you, peers, elements):
            try c.encode("room-state", forKey: .type)
            try c.encode(proto, forKey: .proto)
            try c.encode(you, forKey: .you)
            try c.encode(peers, forKey: .peers)
            try c.encode(elements, forKey: .elements)
        case let .peerJoined(peer):
            try c.encode("peer-joined", forKey: .type)
            try c.encode(peer, forKey: .peer)
        case let .peerLeft(peerId):
            try c.encode("peer-left", forKey: .type)
            try c.encode(peerId, forKey: .peerId)
        case let .presence(peerId, presence):
            try c.encode("presence", forKey: .type)
            try c.encode(peerId, forKey: .peerId)
            try c.encode(presence, forKey: .presence)
        case let .pointer(peerId, pointer):
            try c.encode("pointer", forKey: .type)
            try c.encode(peerId, forKey: .peerId)
            try c.encode(pointer, forKey: .pointer)
        case let .elementUpdates(elements):
            try c.encode("element-updates", forKey: .type)
            try c.encode(elements, forKey: .elements)
        case let .sceneSnapshot(elements):
            try c.encode("scene-snapshot", forKey: .type)
            try c.encode(elements, forKey: .elements)
        case let .ping(t):
            try c.encode("ping", forKey: .type)
            try c.encode(t, forKey: .t)
        case let .ack(t):
            try c.encode("ack", forKey: .type)
            try c.encode(t, forKey: .t)
        }
    }
}

/// Encode/decode protocol messages on the wire (JSON v1).
public enum CollabCodec {
    /// Canonical encoding: compact, sorted keys — byte-identical to the TS
    /// `canonicalEncode`, so both clients produce the same frames.
    public static func encode(_ message: CollabMessage) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(message)
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    public static func decode(_ json: String) throws -> CollabMessage {
        try JSONDecoder().decode(CollabMessage.self, from: Data(json.utf8))
    }
}
