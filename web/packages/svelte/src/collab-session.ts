import type { ExcalidrawElement } from "@xs/model";
import {
  type Message,
  PROTOCOL_VERSION,
  type Peer,
  type PointerPos,
  type Presence,
  decode,
  encode,
  message,
} from "@xs/protocol";

/**
 * The minimal transport `CollabSession` needs — satisfied by the browser's
 * native `WebSocket` (see {@link browserSocket}) and by the `ws` package in
 * tests, so the session logic is transport-agnostic and unit-testable.
 */
export interface CollabSocket {
  send(data: string): void;
  close(): void;
  onOpen(handler: () => void): void;
  onMessage(handler: (data: string) => void): void;
  onClose(handler: () => void): void;
}

/** A remote peer's live cursor + selection, for rendering presence. */
export interface RemoteCursor {
  peer: Peer;
  pointer: PointerPos | null;
  selectedIds: string[];
  tool: string;
}

export interface CollabHooks {
  /** Replace the whole scene (on `room-state` / `scene-snapshot`). */
  onScene: (elements: ExcalidrawElement[]) => void;
  /** Merge a versioned remote batch (on `element-updates`). */
  onRemoteElements: (elements: ExcalidrawElement[]) => void;
  /** Roster or cursor change — refresh presence UI. */
  onPresence?: () => void;
}

/**
 * Client side of the collaboration protocol: opens a room, mirrors local edits
 * to peers as `element-updates`, applies remote edits (the store reconciles by
 * `version`/`versionNonce`), and tracks peer presence/cursors. Speaks the exact
 * `@xs/protocol` wire format the Swift client speaks, so an iOS device and a web
 * browser share one room. (parity: the Swift `CollabClient`.)
 */
export class CollabSession {
  readonly peers = new Map<string, Peer>();
  readonly cursors = new Map<string, RemoteCursor>();
  you: string | null = null;
  connected = false;

  constructor(
    private readonly socket: CollabSocket,
    private readonly peer: Peer,
    private readonly room: string,
    private readonly hooks: CollabHooks,
  ) {
    socket.onOpen(() => {
      this.connected = true;
      this.send(message("join", { protocol: PROTOCOL_VERSION, room: this.room, peer: this.peer }));
    });
    socket.onMessage((data) => {
      let msg: Message;
      try {
        msg = decode(data);
      } catch {
        return;
      }
      this.handle(msg);
    });
    socket.onClose(() => {
      this.connected = false;
    });
  }

  private send(msg: Message): void {
    this.socket.send(encode(msg));
  }

  private handle(msg: Message): void {
    switch (msg.type) {
      case "room-state":
        this.you = msg.you;
        this.peers.clear();
        for (const p of msg.peers) if (p.id !== this.you) this.peers.set(p.id, p);
        this.hooks.onScene(msg.elements);
        this.hooks.onPresence?.();
        break;
      case "peer-joined":
        this.peers.set(msg.peer.id, msg.peer);
        this.hooks.onPresence?.();
        break;
      case "peer-left":
        this.peers.delete(msg.peerId);
        this.cursors.delete(msg.peerId);
        this.hooks.onPresence?.();
        break;
      case "presence":
        this.applyPresence(msg.peerId, msg.presence);
        break;
      case "pointer":
        this.applyPointer(msg.peerId, msg.pointer);
        break;
      case "element-updates":
        this.hooks.onRemoteElements(msg.elements);
        break;
      case "scene-snapshot":
        this.hooks.onScene(msg.elements);
        break;
      default:
        break; // join/leave/ping/ack are not inbound to a client
    }
  }

  private cursorFor(peerId: string): RemoteCursor | null {
    const existing = this.cursors.get(peerId);
    if (existing !== undefined) return existing;
    const peer = this.peers.get(peerId);
    if (peer === undefined) return null;
    const created: RemoteCursor = { peer, pointer: null, selectedIds: [], tool: "selection" };
    this.cursors.set(peerId, created);
    return created;
  }

  private applyPresence(peerId: string, presence: Presence): void {
    const cursor = this.cursorFor(peerId);
    if (cursor === null) return;
    cursor.pointer = presence.pointer;
    cursor.selectedIds = presence.selectedIds;
    cursor.tool = presence.tool;
    this.hooks.onPresence?.();
  }

  private applyPointer(peerId: string, pointer: PointerPos): void {
    const cursor = this.cursorFor(peerId);
    if (cursor === null) return;
    cursor.pointer = pointer;
    this.hooks.onPresence?.();
  }

  // ── Outbound ────────────────────────────────────────────────────────────────

  /** Broadcast changed elements (with their versions) to the room. */
  broadcastElements(elements: ExcalidrawElement[]): void {
    if (elements.length > 0) this.send(message("element-updates", { elements }));
  }

  /** Broadcast cursor + selection + tool. */
  sendPresence(presence: Presence): void {
    if (this.you !== null) this.send(message("presence", { peerId: this.you, presence }));
  }

  /** Broadcast a live pointer position (lossy). */
  sendPointer(pointer: PointerPos): void {
    if (this.you !== null) this.send(message("pointer", { peerId: this.you, pointer }));
  }

  /** Leave the room and close the socket. */
  leave(): void {
    if (this.you !== null) this.send(message("leave", { peerId: this.you }));
    this.socket.close();
  }
}

/** Wrap a browser `WebSocket` as a {@link CollabSocket}. */
export function browserSocket(url: string): CollabSocket {
  const ws = new WebSocket(url);
  return {
    send: (data) => ws.send(data),
    close: () => ws.close(),
    onOpen: (h) => ws.addEventListener("open", () => h()),
    onMessage: (h) => ws.addEventListener("message", (e) => h(String((e as MessageEvent).data))),
    onClose: (h) => ws.addEventListener("close", () => h()),
  };
}
