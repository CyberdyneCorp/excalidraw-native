import type { EditorStore } from "@cyberdynecorp/excalidraw-svelte";
import * as Y from "yjs";
import { type YElement, type YElements, readDocElements, syncElementsToDoc } from "./mapping.js";

/** Origin tag on transactions this adapter writes, so its observer skips echoes. */
const ORIGIN_LOCAL = Symbol("excalidraw-yjs:local");

/** Local peer identity, mirrored to other peers via Yjs awareness. */
export interface PeerIdentity {
  id: string;
  name: string;
  color: string;
}

/** A remote peer's live cursor + selection, reconstructed from Yjs awareness. */
export interface RemotePresence {
  peer: PeerIdentity;
  pointer: { x: number; y: number } | null;
  selectedIds: string[];
  tool: string;
}

/**
 * The slice of the Yjs `Awareness` protocol the adapter uses. Typed structurally
 * so the package needs no `y-protocols` dependency — pass `provider.awareness`
 * from any provider (y-websocket, Hocuspocus, a custom gateway, …).
 */
export interface AwarenessLike {
  readonly clientID: number;
  setLocalState(state: Record<string, unknown> | null): void;
  getStates(): Map<number, Record<string, unknown>>;
  on(event: "change", handler: () => void): void;
  off(event: "change", handler: () => void): void;
}

export interface YjsCollabOptions {
  /** Root `Y.Map` key holding the id→element maps. Default `"elements"`. Point
   * this at your own convention to embed the board in a shared doc. */
  elementsKey?: string;
  /** Yjs `Awareness` (e.g. `provider.awareness`) for presence/cursors. */
  awareness?: AwarenessLike;
  /** This client's identity, published to awareness. Required for presence. */
  peer?: PeerIdentity;
  /** Called whenever remote presence changes, so the UI can redraw cursors. */
  onPresence?: (presences: RemotePresence[]) => void;
}

const AWARENESS_KEY = "excalidraw";

/**
 * Two-way binds an {@link EditorStore} to a Yjs `Y.Doc` (issue #11): local edits
 * are mirrored into the doc field-by-field; remote doc changes are reconstructed
 * into the editor. Yjs does the merging, so this is a *parallel* engine that
 * bypasses the element-LWW `reconcileElements` entirely — the canonical core is
 * unchanged. Provider-agnostic: bring your own `Y.Doc` + provider.
 *
 * ```ts
 * const collab = new YjsCollab(store, ydoc, { awareness: provider.awareness, peer });
 * collab.start();
 * // collab.stop();
 * ```
 */
export class YjsCollab {
  private readonly yElements: YElements;
  private unsubscribeStore: (() => void) | null = null;
  private unsubscribeCursor: (() => void) | null = null;
  private docObserver: (() => void) | null = null;
  private awarenessObserver: (() => void) | null = null;
  /** Guards against the doc→editor apply re-triggering an editor→doc flush. */
  private applying = false;
  private started = false;

  constructor(
    private readonly store: EditorStore,
    private readonly doc: Y.Doc,
    private readonly options: YjsCollabOptions = {},
  ) {
    this.yElements = doc.getMap<YElement>(options.elementsKey ?? "elements");
  }

  /** Begin two-way syncing. Seeds the doc with any local scene, then hydrates
   * the editor from the (now merged) doc, and wires both directions + presence. */
  start(): void {
    if (this.started) return;
    this.started = true;

    // Namespace this client's generated element ids by the doc's unique clientID,
    // so two peers never mint the same id and clobber each other in the shared
    // Y.Map (parity with the LWW session's idPrefix).
    this.store.controller.idPrefix = `y${this.doc.clientID}-`;

    // Seed local elements into the doc (merges with whatever the room has),
    // then hydrate the editor from the union.
    if (this.store.scene.elements.length > 0) this.flushLocal();
    this.applyFromDoc();

    this.unsubscribeStore = this.store.onChange(() => this.flushLocal());

    const observer = (_events: unknown, txn: Y.Transaction): void => {
      if (txn.origin === ORIGIN_LOCAL) return; // skip our own writes
      this.applyFromDoc();
    };
    this.docObserver = () => this.yElements.unobserveDeep(observer);
    this.yElements.observeDeep(observer);

    this.startAwareness();
  }

  /** Stop syncing and clear this client's presence. */
  stop(): void {
    if (!this.started) return;
    this.started = false;
    this.unsubscribeStore?.();
    this.unsubscribeStore = null;
    this.unsubscribeCursor?.();
    this.unsubscribeCursor = null;
    this.docObserver?.();
    this.docObserver = null;
    this.awarenessObserver?.();
    this.awarenessObserver = null;
    this.store.externalCursors = [];
    this.options.awareness?.setLocalState(null);
  }

  // ── editor ⇄ doc ────────────────────────────────────────────────────────────

  /** Mirror the editor's current elements into the doc (only changed fields). */
  private flushLocal(): void {
    if (this.applying) return;
    syncElementsToDoc(this.doc, this.yElements, this.store.scene.elements, ORIGIN_LOCAL, Y.Map);
    this.publishSelection();
  }

  /** Reconstruct the scene from the doc and apply it to the editor (no echo). */
  private applyFromDoc(): void {
    this.applying = true;
    try {
      this.store.applyExternalElements(readDocElements(this.yElements));
    } finally {
      this.applying = false;
    }
  }

  // ── presence / cursors (Yjs awareness) ──────────────────────────────────────

  private startAwareness(): void {
    const { awareness, peer } = this.options;
    if (awareness === undefined || peer === undefined) return;
    const handler = (): void => {
      const presences = this.remotePresences();
      // Feed remote cursors into the editor overlay (visual parity with the LWW
      // session, which renders cursors from `store.remoteCursors`).
      this.store.externalCursors = presences
        .filter((p) => p.pointer !== null)
        .map((p) => ({
          color: p.peer.color,
          name: p.peer.name,
          x: (p.pointer as { x: number; y: number }).x,
          y: (p.pointer as { x: number; y: number }).y,
        }));
      this.store.revision += 1; // redraw the overlay
      this.options.onPresence?.(presences);
    };
    awareness.on("change", handler);
    this.awarenessObserver = () => awareness.off("change", handler);
    // Publish the local cursor as it moves (Canvas calls store.trackPointer).
    this.unsubscribeCursor = this.store.onCursorMove((scene) => this.setCursor(scene));
    this.publishSelection();
  }

  /** Publish this client's selection + active tool to awareness. */
  private publishSelection(): void {
    const { awareness, peer } = this.options;
    if (awareness === undefined || peer === undefined) return;
    const prev = awareness.getStates().get(awareness.clientID)?.[AWARENESS_KEY] as
      | { pointer?: { x: number; y: number } | null }
      | undefined;
    awareness.setLocalState({
      [AWARENESS_KEY]: {
        peer,
        pointer: prev?.pointer ?? null,
        selectedIds: [...this.store.controller.selectedIDs],
        tool: this.store.activeTool,
      },
    });
  }

  /** Publish this client's live cursor position (call on pointer move). */
  setCursor(pointer: { x: number; y: number } | null): void {
    const { awareness, peer } = this.options;
    if (awareness === undefined || peer === undefined) return;
    awareness.setLocalState({
      [AWARENESS_KEY]: {
        peer,
        pointer,
        selectedIds: [...this.store.controller.selectedIDs],
        tool: this.store.activeTool,
      },
    });
  }

  /** Remote peers' live cursors/selection (excludes this client). */
  remotePresences(): RemotePresence[] {
    const { awareness } = this.options;
    if (awareness === undefined) return [];
    const out: RemotePresence[] = [];
    for (const [clientId, state] of awareness.getStates()) {
      if (clientId === awareness.clientID) continue;
      const p = state[AWARENESS_KEY] as RemotePresence | undefined;
      if (p?.peer !== undefined) out.push(p);
    }
    return out;
  }
}
