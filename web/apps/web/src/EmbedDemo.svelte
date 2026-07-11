<script lang="ts">
// Exercises the public embedding API exactly as a third-party client would.
import type { EditorStore } from "@cyberdynecorp/excalidraw-svelte";
import type { Scene } from "@cyberdynecorp/excalidraw-svelte/model";
import { Excalidraw, type UIOptions } from "@cyberdynecorp/excalidraw-svelte/ui";

const params = new URLSearchParams(location.search);
const viewMode = params.get("viewMode") === "1";
const themed = params.get("themed") === "1";
const minimal = params.get("minimal") === "1";

// A deliberately reduced UI: three tools, no style panel, no app menu.
const uiOptions: UIOptions | undefined = minimal
  ? {
      toolbar: { tools: ["selection", "rectangle", "arrow"], lock: false, image: false, more: false },
      panel: false,
      menu: false,
      quickActions: false,
    }
  : undefined;

let changes = $state(0);
function onReady(store: EditorStore): void {
  (window as unknown as { __store?: EditorStore }).__store = store;
}
function onChange(_scene: Scene): void {
  changes += 1;
  (window as unknown as { __changes?: number }).__changes = changes;
}
</script>

<div class="host" class:themed>
  <Excalidraw
    {onReady}
    {onChange}
    {viewMode}
    {uiOptions}
    overlayColors={themed ? { accent: "#ff0000", bindingHighlight: "#00ff00" } : undefined}
  >
    {#snippet topRight()}
      <button data-testid="host-button" class="host-button">Host button</button>
    {/snippet}
  </Excalidraw>
</div>

<style>
  .host { position: absolute; inset: 0; }
  /* A client re-themes the editor purely through the documented tokens. */
  .themed :global(.app) {
    --excal-island: #10233a;
    --excal-ink: #e8f1ff;
    --excal-accent-bg: #ff0000;
    --excal-accent-ink: #ffffff;
  }
  .host-button {
    padding: 8px 12px;
    border-radius: 8px;
    border: 1px solid #0003;
    background: #ffd43b;
    cursor: pointer;
  }
</style>
