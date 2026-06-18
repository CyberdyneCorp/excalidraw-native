import { EditorStore } from "@cyberdynecorp/excalidraw-svelte";
import { Point } from "@cyberdynecorp/excalidraw-svelte/math";
import { SceneDocument } from "@cyberdynecorp/excalidraw-svelte/model";
import { reconcileElements } from "@cyberdynecorp/excalidraw-svelte/protocol";
import { describe, expect, it } from "vitest";
import * as Y from "yjs";
import { readDocElements } from "./mapping.js";
import { applyEdit, elementsKey, rect } from "./test-helpers.js";
import { type AwarenessLike, type PeerIdentity, YjsCollab } from "./yjs-collab.js";

/** Draw a rectangle through the real pointer pipeline (a genuine local edit). */
function drawRect(store: EditorStore, from = new Point(10, 10), to = new Point(110, 70)): void {
  store.selectTool("rectangle");
  store.pointer("down", from);
  store.pointer("move", to);
  store.pointer("up", to);
}

function live(doc: Y.Doc) {
  return readDocElements(elementsKey(doc)).filter((e) => !e.isDeleted);
}

describe("YjsCollab — editor ⇄ Y.Doc", () => {
  it("mirrors a local edit into the Y.Doc", () => {
    const store = new EditorStore();
    const doc = new Y.Doc();
    new YjsCollab(store, doc).start();

    drawRect(store);

    expect(live(doc)).toHaveLength(1);
    expect(live(doc)[0]?.type).toBe("rectangle");
  });

  it("applies a remote Y.Doc change into the editor", () => {
    const store = new EditorStore();
    const doc = new Y.Doc();
    new YjsCollab(store, doc).start();

    applyEdit(doc, [rect("remote-1", { index: "a0" })]); // non-local origin → observed

    expect(store.scene.visibleElements.map((e) => e.id)).toContain("remote-1");
  });

  it("two editors over two docs converge when updates are exchanged", () => {
    const storeA = new EditorStore();
    const storeB = new EditorStore();
    const docA = new Y.Doc();
    const docB = new Y.Doc();
    new YjsCollab(storeA, docA).start();
    new YjsCollab(storeB, docB).start();

    drawRect(storeA);
    Y.applyUpdate(docB, Y.encodeStateAsUpdate(docA)); // A → B over the "wire"

    expect(storeB.scene.visibleElements).toHaveLength(1);
    expect(storeB.scene.visibleElements[0]?.type).toBe("rectangle");
  });

  it("does not echo its own writes back into the doc", () => {
    const store = new EditorStore();
    const doc = new Y.Doc();
    new YjsCollab(store, doc).start();
    drawRect(store);
    const id = live(doc)[0]?.id as string;
    const versionAfterDraw = elementsKey(doc).get(id)?.get("version");
    // A no-op local change (re-select same tool) must not rewrite element fields.
    store.selectTool("selection");
    expect(elementsKey(doc).get(id)?.get("version")).toBe(versionAfterDraw);
  });

  it("FIDELITY: a Yjs-synced scene is valid .excalidraw and interoperates with the LWW engine", () => {
    const store = new EditorStore();
    const doc = new Y.Doc();
    new YjsCollab(store, doc).start();
    drawRect(store);

    // Still a valid .excalidraw document.
    const reloaded = SceneDocument.decode(SceneDocument.encode(store.scene));
    expect(reloaded.visibleElements).toHaveLength(store.scene.visibleElements.length);

    // The LWW engine reconciles the Yjs-produced elements unchanged.
    const reconciled = reconcileElements([], store.scene.elements);
    expect(reconciled.map((e) => e.id).sort()).toEqual(
      store.scene.elements.map((e) => e.id).sort(),
    );
  });
});

// A minimal in-memory Awareness double (avoids a y-protocols dependency in tests).
class FakeAwareness implements AwarenessLike {
  readonly clientID: number;
  private readonly states = new Map<number, Record<string, unknown>>();
  private readonly handlers = new Set<() => void>();
  constructor(clientID: number) {
    this.clientID = clientID;
  }
  setLocalState(state: Record<string, unknown> | null): void {
    if (state === null) this.states.delete(this.clientID);
    else this.states.set(this.clientID, state);
    for (const h of this.handlers) h();
  }
  getStates(): Map<number, Record<string, unknown>> {
    return this.states;
  }
  on(_event: "change", handler: () => void): void {
    this.handlers.add(handler);
  }
  off(_event: "change", handler: () => void): void {
    this.handlers.delete(handler);
  }
  /** Inject a remote peer's state (as another client would over the wire). */
  injectRemote(clientID: number, state: Record<string, unknown>): void {
    this.states.set(clientID, state);
    for (const h of this.handlers) h();
  }
}

describe("YjsCollab — presence via Yjs awareness", () => {
  const peer: PeerIdentity = { id: "me", name: "Me", color: "#3b82f6" };

  it("publishes local selection/tool and a live cursor to awareness", () => {
    const store = new EditorStore();
    const doc = new Y.Doc();
    const awareness = new FakeAwareness(1);
    const collab = new YjsCollab(store, doc, { awareness, peer });
    collab.start();

    collab.setCursor({ x: 42, y: 7 });
    const mine = awareness.getStates().get(1)?.excalidraw as {
      peer: PeerIdentity;
      pointer: unknown;
    };
    expect(mine.peer).toEqual(peer);
    expect(mine.pointer).toEqual({ x: 42, y: 7 });
  });

  it("reports remote presences and excludes self", () => {
    const store = new EditorStore();
    const doc = new Y.Doc();
    const awareness = new FakeAwareness(1);
    let reported = 0;
    const collab = new YjsCollab(store, doc, {
      awareness,
      peer,
      onPresence: () => {
        reported += 1;
      },
    });
    collab.start();

    awareness.injectRemote(2, {
      excalidraw: {
        peer: { id: "u2", name: "Two", color: "#f00" },
        pointer: { x: 1, y: 2 },
        selectedIds: [],
        tool: "selection",
      },
    });

    const remotes = collab.remotePresences();
    expect(remotes.map((p) => p.peer.id)).toEqual(["u2"]);
    expect(reported).toBeGreaterThan(0);
  });
});
