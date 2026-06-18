# @cyberdynecorp/excalidraw-yjs

An **optional Yjs/CRDT collaboration adapter** for [`@cyberdynecorp/excalidraw-svelte`](https://github.com/leonardoaraujosantos/excalidraw-swift-web/tree/main/web/packages/excalidraw-svelte). It two-way binds an `EditorStore` to a Yjs `Y.Doc`, so you can collaborate over the **entire Yjs provider ecosystem** (y-websocket, Hocuspocus, Liveblocks, PartyKit, y-webrtc, or a custom gateway) and get **field-level merge** for concurrent edits to the same element.

> The canonical engine stays the built-in **element-LWW** (`version`/`versionNonce` + `reconcileElements`) shared byte-identically with the Swift twin. This adapter is **additive and optional** — a *parallel* engine that bypasses `reconcileElements` (Yjs does the merging). The core library takes **no** `yjs` dependency.

## When to use which backend

| | Native relay (`@cyberdynecorp/excalidraw-relay`) | Yjs adapter (this package) |
| --- | --- | --- |
| Engine | element-LWW, shared with Swift | Yjs CRDT |
| Cross-platform with the iOS/Swift app | ✅ byte-identical wire protocol | ❌ web-only |
| Concurrent edits to the **same element** | last-writer-wins (one side clobbered) | **field-level merge** (recolor + move both survive) |
| Infrastructure | our small Node relay | your existing Yjs provider + backend |
| Offline merge | reconciled on rejoin | CRDT convergence |

Choose the relay for iPad↔browser parity; choose Yjs if you already run Yjs infrastructure or need field-level merge.

## Install

```sh
npm install @cyberdynecorp/excalidraw-yjs yjs y-websocket
```

`yjs` is a **peer dependency**; the provider (`y-websocket`, etc.) is your choice.

## Usage

```ts
import { EditorStore } from "@cyberdynecorp/excalidraw-svelte";
import { YjsCollab } from "@cyberdynecorp/excalidraw-yjs";
import * as Y from "yjs";
import { WebsocketProvider } from "y-websocket";

const store = new EditorStore();
const ydoc = new Y.Doc();
const provider = new WebsocketProvider("wss://relay.example", "room-123", ydoc);

const collab = new YjsCollab(store, ydoc, {
  awareness: provider.awareness, // presence/cursors via Yjs awareness
  peer: { id: "u1", name: "Ada", color: "#3b82f6" },
  onPresence: (peers) => {
    /* redraw remote cursors */
  },
});
collab.start(); // two-way bind
collab.setCursor({ x, y }); // publish live cursor on pointer move
// collab.stop();
```

Embedding in an existing shared doc? Point `elementsKey` at your own convention so the board coexists with other CRDT content:

```ts
new YjsCollab(store, ydoc, { elementsKey: "excalidraw" });
```

Any provider that exposes a `Y.Doc` (and optionally an `awareness`) works — including a **custom WebSocket gateway** (the adapter is provider-agnostic; it only touches the `Y.Doc`).

## Mapping (v1)

- The scene is a top-level `Y.Map` keyed by element id; each value is a per-element `Y.Map` of that element's fields — so **different fields of the same element merge** (the headline win over LWW).
- **Scalars** (`x`, `y`, `strokeColor`, `index`, …) merge per field.
- **Arrays/objects** (`points`, `groupIds`, `boundElements`, `pressures`, bindings, `customData`) are stored as **atomic values** in v1 — a concurrent edit to one of these is whole-value LWW within Yjs. Collaborative point-level editing is a future tier.
- **Soft delete** via an `isDeleted` tombstone; the per-element `Y.Map` is never hard-removed.
- **Z-order** is driven by the fractional `index` field, never `Y.Map` iteration order.
- `version`/`versionNonce` are carried (not used to reconcile) so a Yjs-synced scene still round-trips `.excalidraw` and interoperates with the LWW engine and the Swift twin.

## v1 limitations

- **Web-only.** The Swift twin stays pure-Swift; a yrs CRDT over FFI is out of scope (see issue #11).
- **Atomic arrays.** `points`/`groupIds`/`boundElements`/`pressures` are whole-value LWW within Yjs.

## License

MIT © Cyberdyne Corp AI
