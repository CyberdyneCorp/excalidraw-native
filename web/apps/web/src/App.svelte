<script lang="ts">
// The demo app is now a thin consumer of the published editor component: it
// wires collaboration from URL parameters and exposes the store to the E2E
// suite. All chrome lives in `@cyberdynecorp/excalidraw-svelte/ui`.
import { browserSocket, reconnectingSocket } from "@cyberdynecorp/excalidraw-svelte";
import type { EditorStore } from "@cyberdynecorp/excalidraw-svelte";
import {
  Excalidraw,
  type ExportImageOptions,
  exportPngBytes,
} from "@cyberdynecorp/excalidraw-svelte/ui";
import { type AwarenessLike, YjsCollab } from "@cyberdynecorp/excalidraw-yjs";
import { Awareness } from "y-protocols/awareness";
import * as Y from "yjs";
import { BroadcastChannelProvider } from "./lib/yjs-broadcast-provider";

const params = new URLSearchParams(location.search);
const palette = ["#e64980", "#4263eb", "#0ca678", "#f08c00", "#ae3ec9"];
const peerOf = () => ({
  id: `web-${Math.random().toString(36).slice(2, 8)}`,
  name: params.get("name") ?? "Guest",
  color: palette[Math.floor(Math.random() * palette.length)]!,
});

function onReady(store: EditorStore): void {
  // Expose the store and the export pipeline for the E2E suite.
  (window as unknown as { __store?: EditorStore }).__store = store;
  (window as unknown as { __exportPng?: () => Promise<Uint8Array | null> }).__exportPng = () =>
    exportPngBytes(store, { scale: 1, background: true, selectionOnly: false, embed: true });
  (
    window as unknown as { __exportPngWith?: (o: ExportImageOptions) => Promise<Uint8Array | null> }
  ).__exportPngWith = (o: ExportImageOptions) => exportPngBytes(store, o);

  // Auto-join a collaboration room from the URL: ?relay=ws://…&room=…&name=…
  const relayUrl = params.get("relay");
  const roomName = params.get("room");
  if (relayUrl !== null && roomName !== null) {
    store.startCollab(
      reconnectingSocket(() => browserSocket(relayUrl)),
      peerOf(),
      roomName,
    );
  }

  // Or join a Yjs/CRDT room: ?yjs=<room> (same-origin BroadcastChannel provider).
  const yjsRoom = params.get("yjs");
  if (yjsRoom !== null) {
    const ydoc = new Y.Doc();
    const awareness = new Awareness(ydoc);
    const provider = new BroadcastChannelProvider(ydoc, yjsRoom, awareness);
    const collab = new YjsCollab(store, ydoc, {
      awareness: awareness as unknown as AwarenessLike,
      peer: peerOf(),
    });
    collab.start();
    (window as unknown as { __yjs?: unknown }).__yjs = { doc: ydoc, collab, provider, awareness };
  }
}
</script>

<Excalidraw {onReady} />
