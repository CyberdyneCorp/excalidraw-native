import { type Awareness, applyAwarenessUpdate, encodeAwarenessUpdate } from "y-protocols/awareness";
import * as Y from "yjs";

/**
 * A minimal same-origin Yjs provider over `BroadcastChannel` — zero server, no
 * native deps. It syncs a `Y.Doc` (and, optionally, a Yjs `Awareness`) across
 * browser tabs/pages sharing an origin: local updates are broadcast; a joining
 * peer requests the current state and existing peers reply with a diff (so a
 * reload re-hydrates from a live peer).
 *
 * This is the demo app's bundled provider (and what the Yjs E2E uses). The
 * adapter itself is provider-agnostic — in production bring y-websocket,
 * Hocuspocus, or a custom gateway and pass its `Y.Doc` (+ awareness) to
 * `YjsCollab`.
 */
type Message =
  | { t: "update"; u: Uint8Array }
  | { t: "query"; sv: Uint8Array }
  | { t: "awareness"; u: Uint8Array };

export class BroadcastChannelProvider {
  private readonly channel: BroadcastChannel;

  constructor(
    private readonly doc: Y.Doc,
    room: string,
    private readonly awareness?: Awareness,
  ) {
    this.channel = new BroadcastChannel(`excalidraw-yjs:${room}`);
    this.channel.onmessage = (event: MessageEvent<Message>) => this.onMessage(event.data);
    this.doc.on("update", this.onUpdate);
    this.awareness?.on("update", this.onAwarenessUpdate);
    // Ask any live peer for the state we're missing (late-join / reload).
    this.channel.postMessage({ t: "query", sv: Y.encodeStateVector(this.doc) } satisfies Message);
  }

  private readonly onUpdate = (update: Uint8Array, origin: unknown): void => {
    if (origin === this) return; // don't echo updates we just applied
    this.channel.postMessage({ t: "update", u: update } satisfies Message);
  };

  private readonly onAwarenessUpdate = (
    changes: { added: number[]; updated: number[]; removed: number[] },
    origin: unknown,
  ): void => {
    if (origin === this || this.awareness === undefined) return;
    const clients = [...changes.added, ...changes.updated, ...changes.removed];
    this.channel.postMessage({
      t: "awareness",
      u: encodeAwarenessUpdate(this.awareness, clients),
    } satisfies Message);
  };

  private onMessage(message: Message): void {
    if (message.t === "update") {
      Y.applyUpdate(this.doc, message.u, this);
    } else if (message.t === "awareness") {
      if (this.awareness !== undefined) applyAwarenessUpdate(this.awareness, message.u, this);
    } else {
      // Reply with the doc state the requester is missing, plus our awareness so
      // a joiner immediately sees existing peers.
      this.channel.postMessage({
        t: "update",
        u: Y.encodeStateAsUpdate(this.doc, message.sv),
      } satisfies Message);
      if (this.awareness !== undefined && this.awareness.getStates().size > 0) {
        this.channel.postMessage({
          t: "awareness",
          u: encodeAwarenessUpdate(this.awareness, [...this.awareness.getStates().keys()]),
        } satisfies Message);
      }
    }
  }

  destroy(): void {
    this.doc.off("update", this.onUpdate);
    this.awareness?.off("update", this.onAwarenessUpdate);
    this.channel.close();
  }
}
