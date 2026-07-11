<script lang="ts">
import { EditorStore, browserSocket, reconnectingSocket } from "@cyberdynecorp/excalidraw-svelte";
import type { Tool } from "@cyberdynecorp/excalidraw-svelte/editor";
import { FontFamily } from "@cyberdynecorp/excalidraw-svelte/model";
import type { Arrowhead, FillStyle, StrokeStyle, TextAlign } from "@cyberdynecorp/excalidraw-svelte/model";
import { type AwarenessLike, YjsCollab } from "@cyberdynecorp/excalidraw-yjs";
import { Awareness } from "y-protocols/awareness";
import * as Y from "yjs";
import Canvas from "./lib/Canvas.svelte";
import { BroadcastChannelProvider } from "./lib/yjs-broadcast-provider";

const store = new EditorStore();
// Expose the store for end-to-end tests to assert against the scene.
(window as unknown as { __store?: EditorStore }).__store = store;

// Auto-join a collaboration room from the URL: ?relay=ws://…&room=…&name=…
const params = new URLSearchParams(location.search);
const relayUrl = params.get("relay");
const roomName = params.get("room");
if (relayUrl !== null && roomName !== null) {
  const palette = ["#e64980", "#4263eb", "#0ca678", "#f08c00", "#ae3ec9"];
  const peer = {
    id: `web-${Math.random().toString(36).slice(2, 8)}`,
    name: params.get("name") ?? "Guest",
    color: palette[Math.floor(Math.random() * palette.length)]!,
  };
  store.startCollab(
    reconnectingSocket(() => browserSocket(relayUrl)),
    peer,
    roomName,
  );
}

// Or join a Yjs/CRDT room from the URL: ?yjs=<room> (same-origin BroadcastChannel
// provider; the adapter itself works with any provider). Exposed for E2E tests.
const yjsRoom = params.get("yjs");
if (yjsRoom !== null) {
  const palette = ["#e64980", "#4263eb", "#0ca678", "#f08c00", "#ae3ec9"];
  const peer = {
    id: `web-${Math.random().toString(36).slice(2, 8)}`,
    name: params.get("name") ?? "Guest",
    color: palette[Math.floor(Math.random() * palette.length)]!,
  };
  const ydoc = new Y.Doc();
  const awareness = new Awareness(ydoc);
  const provider = new BroadcastChannelProvider(ydoc, yjsRoom, awareness);
  const collab = new YjsCollab(store, ydoc, {
    awareness: awareness as unknown as AwarenessLike,
    peer,
  });
  collab.start();
  (window as unknown as { __yjs?: unknown }).__yjs = { doc: ydoc, collab, provider, awareness };
}
// The store is plain TS, so its reads aren't reactive on their own. Poll the
// revision counter and expose store-derived UI state through `view`, which
// re-derives whenever `rev` changes (fine-grained reactivity in runes mode).
let rev = $state(0);
$effect(() => {
  const id = setInterval(() => {
    rev = store.revision;
  }, 40);
  return () => clearInterval(id);
});
const view = $derived.by(() => {
  void rev;
  return {
    tool: store.activeTool,
    canUndo: store.canUndo,
    canRedo: store.canRedo,
    zoom: store.zoomPercent,
    theme: store.theme,
    stats: store.selectionStats,
    editing: store.editingText,
    table: store.selectedTableGroup,
    chart: store.editingChart,
    peers: store.collab === null ? [] : [...store.collab.peers.values()],
    selectedCount: store.selectedCount,
    canGroup: store.canGroupSelection,
    canUngroup: store.canUngroupSelection,
  };
});

// The style panel shows contextually: with a selection, or while a tool that
// creates styled elements is active (excalidraw's left panel behaviour).
const styledTools = new Set<Tool>([
  "rectangle",
  "diamond",
  "ellipse",
  "arrow",
  "line",
  "freedraw",
  "text",
  "frame",
]);
const panelOpen = $derived(view.selectedCount > 0 || styledTools.has(view.tool));
// The style panel starts collapsed; a small toggle island expands it.
let panelExpanded = $state(false);

// Excalidraw's preset palettes (identical hex values, so files opened on
// excalidraw.com highlight the same swatches).
const STROKE_SWATCHES = ["#1e1e1e", "#e03131", "#2f9e44", "#1971c2", "#f08c00"];
const BG_SWATCHES = ["transparent", "#ffc9c9", "#b2f2bb", "#a5d8ff", "#ffec99"];
const FONT_FAMILIES = [
  { id: FontFamily.excalifont, label: "Hand-drawn", glyph: "✍" },
  { id: FontFamily.helvetica, label: "Normal", glyph: "A" },
  { id: FontFamily.cascadia, label: "Code", glyph: "‹›" },
];
const FONT_SIZES = [
  { size: 16, label: "S" },
  { size: 20, label: "M" },
  { size: 28, label: "L" },
  { size: 36, label: "XL" },
];
const ARROWHEADS = ["none", "arrow", "triangle", "bar", "dot", "diamond"] as const;

// Style values the panel shows: the first selected element's, falling back to
// the defaults for the next element (excalidraw's reflection rule).
const sel = $derived.by(() => {
  void rev;
  const el = store.controller.selectedElements[0];
  const ci = store.controller.currentItem;
  const textEl = el !== undefined && el.type === "text" ? el : undefined;
  const arrowEl = el !== undefined && el.type === "arrow" ? el : undefined;
  const linearEl = el !== undefined && (el.type === "arrow" || el.type === "line") ? el : undefined;
  const types = new Set(store.controller.selectedElements.map((e) => e.type));
  const arrowType =
    linearEl !== undefined
      ? arrowEl?.elbowed
        ? "elbow"
        : linearEl.roundness !== null
          ? "curved"
          : "straight"
      : ci.elbowed
        ? "elbow"
        : ci.arrowCurved
          ? "curved"
          : "straight";
  return {
    strokeColor: el?.strokeColor ?? ci.strokeColor,
    backgroundColor: el?.backgroundColor ?? ci.backgroundColor,
    fillStyle: el?.fillStyle ?? ci.fillStyle,
    strokeWidth: el?.strokeWidth ?? ci.strokeWidth,
    strokeStyle: el?.strokeStyle ?? ci.strokeStyle,
    roughness: el?.roughness ?? ci.roughness,
    roundEdges: el !== undefined ? el.roundness !== null : ci.roundEdges,
    opacity: el?.opacity ?? ci.opacity,
    fontFamily: textEl?.fontFamily ?? ci.fontFamily,
    fontSize: textEl?.fontSize ?? ci.fontSize,
    textAlign: textEl?.textAlign ?? ci.textAlign,
    arrowType,
    startArrowhead: arrowEl !== undefined ? arrowEl.startArrowhead : ci.startArrowhead,
    endArrowhead: arrowEl !== undefined ? arrowEl.endArrowhead : ci.endArrowhead,
    textContext: view.tool === "text" || types.has("text"),
    arrowContext:
      view.tool === "arrow" || view.tool === "line" || types.has("arrow") || types.has("line"),
  };
});
// The "more tools" dropdown (extra tools + generators), excalidraw-style.
let moreOpen = $state(false);

// Right-click context menu over the canvas (scene coords not needed: it acts
// on the current selection). `null` when hidden.
let menu = $state<{ x: number; y: number } | null>(null);
function openMenu(e: MouseEvent): void {
  e.preventDefault();
  const r = (e.currentTarget as HTMLElement).getBoundingClientRect();
  menu = { x: e.clientX - r.left, y: e.clientY - r.top };
}
function closeMenu(): void {
  menu = null;
}
function runMenu(action: () => void): void {
  action();
  closeMenu();
}

// Minimal inline SVG icons (24px viewBox, stroked in currentColor) — the
// toolbar is icon-only with shortcut badges, like excalidraw's island.
const svg = (body: string) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;
const icons: Record<string, string> = {
  hand: svg(
    '<path d="M8 11.5V5.7a1.45 1.45 0 0 1 2.9 0V10"/><path d="M10.9 10V4.2a1.45 1.45 0 0 1 2.9 0V10"/><path d="M13.8 10.3V5.4a1.45 1.45 0 0 1 2.9 0v6.1"/><path d="M16.7 9.9a1.45 1.45 0 0 1 2.9 0v4.6a7 7 0 0 1-7 7h-1.1c-1.9 0-3.4-.6-4.6-1.8l-3.3-3.4a1.55 1.55 0 0 1 2.2-2.2L8 16.2v-4.7"/>',
  ),
  selection: svg('<path d="M6 3.5 18.5 12l-6 1.3L10 19.5z"/>'),
  rectangle: svg('<rect x="4" y="5" width="16" height="14" rx="2"/>'),
  diamond: svg('<path d="M12 3l8.5 9-8.5 9-8.5-9z"/>'),
  ellipse: svg('<circle cx="12" cy="12" r="8.5"/>'),
  arrow: svg('<path d="M5 19 19 5"/><path d="M11.5 5H19v7.5"/>'),
  line: svg('<path d="M5 17h14"/>'),
  freedraw: svg('<path d="M4.5 19.5l1-4L16.7 4.3a2 2 0 0 1 2.9 3L8.5 18.5l-4 1z"/>'),
  text: svg('<path d="M5.5 6V4.5h13V6"/><path d="M12 4.5v15"/><path d="M9.5 19.5h5"/>'),
  image: svg(
    '<rect x="4" y="5" width="16" height="14" rx="2"/><circle cx="9.2" cy="10" r="1.4"/><path d="M5 17l4.5-4.5 3.5 3.5 2.3-2.3L19 17"/>',
  ),
  eraser: svg(
    '<path d="M7.5 20h11"/><path d="M5 14.5 12.8 6.7a2 2 0 0 1 2.8 0l2.7 2.7a2 2 0 0 1 0 2.8L13.5 17H9.8z"/>',
  ),
  frame: svg('<path d="M4.5 8h15M4.5 16h15M8 4.5v15M16 4.5v15"/>'),
  laser: svg(
    '<circle cx="12" cy="12" r="2.6"/><path d="M12 4.5V6M12 18v1.5M4.5 12H6M18 12h1.5M6.7 6.7l1.1 1.1M16.2 16.2l1.1 1.1M17.3 6.7l-1.1 1.1M7.8 16.2l-1.1 1.1"/>',
  ),
  note: svg('<path d="M5 4.5h14v9.5l-4.5 5.5H5z"/><path d="M14.5 19.5V14H19"/>'),
  table: svg('<rect x="4" y="5" width="16" height="14" rx="1.5"/><path d="M4 10h16M10 10v9M15 10v9"/>'),
  chart: svg(
    '<path d="M4.5 4.5v15h15"/><path d="M8 16v-4M12 16V8M16 16v-6"/>',
  ),
  mermaid: svg(
    '<rect x="4" y="4" width="7.5" height="5" rx="1"/><rect x="12.5" y="15" width="7.5" height="5" rx="1"/><path d="M7.75 9v4.5a2 2 0 0 0 2 2h2.75M16.25 15v-3"/>',
  ),
  sliders: svg(
    '<path d="M5.5 5v5M5.5 14v5M12 5v2.5M12 11.5V19M18.5 5v8M18.5 17v2"/><circle cx="5.5" cy="12" r="1.6"/><circle cx="12" cy="9.5" r="1.6"/><circle cx="18.5" cy="15" r="1.6"/>',
  ),
  chevronLeft: svg('<path d="M14.5 6 9 12l5.5 6"/>'),
  shapes: svg(
    '<rect x="4" y="4" width="8.5" height="8.5" rx="1.5"/><circle cx="16" cy="16" r="4.5"/><path d="M16 4.5v6M13 7.5h6"/>',
  ),
};

const toolDefs: { tool: Tool; badge: string; title: string }[] = [
  { tool: "hand", badge: "H", title: "Hand (panning tool) — H" },
  { tool: "selection", badge: "1", title: "Selection — 1 or V" },
  { tool: "rectangle", badge: "2", title: "Rectangle — 2 or R" },
  { tool: "diamond", badge: "3", title: "Diamond — 3 or D" },
  { tool: "ellipse", badge: "4", title: "Ellipse — 4 or O" },
  { tool: "arrow", badge: "5", title: "Arrow — 5 or A" },
  { tool: "line", badge: "6", title: "Line — 6 or L" },
  { tool: "freedraw", badge: "7", title: "Draw — 7 or P" },
  { tool: "text", badge: "8", title: "Text — 8 or T" },
  { tool: "eraser", badge: "0", title: "Eraser — 0 or E" },
];

let fileInput: HTMLInputElement;

function importImage(e: Event): void {
  const file = (e.currentTarget as HTMLInputElement).files?.[0];
  if (file === undefined) return;
  const reader = new FileReader();
  reader.onload = () => {
    const dataURL = reader.result as string;
    const img = new Image();
    img.onload = () => store.insertImage(dataURL, file.type, img.naturalWidth, img.naturalHeight);
    img.src = dataURL;
  };
  reader.readAsDataURL(file);
}

function pick(tool: Tool): void {
  store.selectTool(tool);
}

/** Focus the on-canvas editor on mount with the caret at the end. The HTML
 * `autofocus` attribute is skipped when another element (e.g. the Note
 * toolbar button that opened the editor) already has focus. */
function focusEditor(node: HTMLTextAreaElement): void {
  node.focus();
  node.setSelectionRange(node.value.length, node.value.length);
}

function downloadSvg(): void {
  const blob = new Blob([store.exportSvg()], { type: "image/svg+xml" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "drawing.svg";
  a.click();
}

function downloadJson(): void {
  const blob = new Blob([store.documentJSON()], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "drawing.excalidraw";
  a.click();
}

const mermaidSample =
  "flowchart TD\n  A[Start] --> B{OK?}\n  B -->|Yes| C[Ship]\n  B -->|No| D[Fix]";

// Letter and number shortcuts, mirroring excalidraw's map (1–8 tools, 9 image,
// 0 eraser).
const toolKeys: Record<string, Tool> = {
  v: "selection",
  r: "rectangle",
  d: "diamond",
  o: "ellipse",
  a: "arrow",
  l: "line",
  p: "freedraw",
  t: "text",
  e: "eraser",
  h: "hand",
  f: "frame",
  k: "laser",
  "1": "selection",
  "2": "rectangle",
  "3": "diamond",
  "4": "ellipse",
  "5": "arrow",
  "6": "line",
  "7": "freedraw",
  "8": "text",
  "0": "eraser",
};

function onKeydown(e: KeyboardEvent): void {
  if (e.key === "Escape" && menu !== null) {
    closeMenu();
    return;
  }
  if (e.key === "Escape" && moreOpen) {
    moreOpen = false;
    return;
  }
  // Escape abandons a click-started arrow awaiting its destination.
  if (e.key === "Escape" && store.cancelPendingArrow()) return;
  // While a text editor is open every key belongs to it — tool shortcuts and
  // delete/backspace must never fire. Escape commits and closes the editor.
  if (store.editingText !== null) {
    if (e.key === "Escape") store.commitText();
    return;
  }
  const target = e.target as HTMLElement | null;
  const tag = target?.tagName ?? "";
  if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
  const mod = e.metaKey || e.ctrlKey;
  if (mod && e.key.toLowerCase() === "z") {
    e.preventDefault();
    if (e.shiftKey) store.redo();
    else store.undo();
    return;
  }
  if (mod && e.key.toLowerCase() === "d") {
    e.preventDefault();
    store.duplicate();
    return;
  }
  if (mod && e.key.toLowerCase() === "a") {
    e.preventDefault();
    store.selectAll();
    return;
  }
  if (e.key === "Backspace" || e.key === "Delete") {
    store.deleteSelected();
    return;
  }
  if (mod) return; // don't let Cmd/Ctrl+digit browser shortcuts switch tools
  if (e.key === "9") {
    fileInput.click(); // 9 = insert image, like excalidraw
    return;
  }
  const tool = toolKeys[e.key.toLowerCase()];
  if (tool !== undefined) store.selectTool(tool);
}
</script>

<svelte:window onkeydown={onKeydown} />

<div class="app" data-theme={view.theme} data-rev={rev}>
  <main class="stage" oncontextmenu={openMenu}>
    <Canvas {store} {rev} />
    {#if view.editing !== null}
      <!-- Container-bound labels (viewW set) centre the caret in the shape:
           text-align centres horizontally, padding-top centres the line block
           vertically and re-centres as lines are added (25px = the editor's
           line-height). -->
      <textarea
        class="text-editor"
        class:centered={view.editing.viewW !== undefined}
        data-testid="text-editor"
        use:focusEditor
        style="left:{view.editing.viewX}px;top:{view.editing.viewY}px{view.editing.viewW
          ? `;width:${view.editing.viewW}px;min-width:0;height:${view.editing.viewH}px;padding-top:${Math.max(
              0,
              ((view.editing.viewH ?? 0) - view.editing.value.split('\n').length * 25) / 2,
            )}px`
          : ''}"
        value={view.editing.value}
        oninput={(e) => store.setEditingText((e.currentTarget as HTMLTextAreaElement).value)}
        onblur={() => store.commitText()}
        onkeydown={(e) => {
          if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            store.commitText();
          } else if (e.key === "Escape") {
            e.preventDefault();
            store.commitText();
          }
        }}
      ></textarea>
    {/if}
    {#if view.chart !== null}
      <div class="island chart-editor" data-testid="chart-editor" style="left:{view.chart.viewX}px;top:{view.chart.viewY}px">
        <label class="inline">Plot
          <select
            data-testid="chart-kind"
            value={view.chart.kind}
            onchange={(e) => store.setChartKind((e.currentTarget as HTMLSelectElement).value as "bar" | "line")}
          >
            <option value="bar">Bar</option>
            <option value="line">Line</option>
          </select>
        </label>
        <label class="inline">Data
          <input
            data-testid="chart-data"
            type="text"
            value={view.chart.values}
            oninput={(e) => store.setChartValues((e.currentTarget as HTMLInputElement).value)}
          />
        </label>
        <button class="chip" data-testid="chart-apply" onclick={() => store.commitChart()}>Apply</button>
        <button class="chip" onclick={() => store.cancelChart()}>Cancel</button>
      </div>
    {/if}
    {#if menu !== null}
      <button
        type="button"
        class="ctx-backdrop"
        aria-label="Dismiss menu"
        onclick={closeMenu}
        oncontextmenu={(e) => {
          e.preventDefault();
          closeMenu();
        }}
      ></button>
      <div class="island context-menu" data-testid="context-menu" style="left:{menu.x}px;top:{menu.y}px">
        <button data-testid="ctx-duplicate" disabled={view.selectedCount === 0} onclick={() => runMenu(() => store.duplicate())}>Duplicate</button>
        <button data-testid="ctx-group" disabled={!view.canGroup} onclick={() => runMenu(() => store.group())}>Group</button>
        <button data-testid="ctx-ungroup" disabled={!view.canUngroup} onclick={() => runMenu(() => store.ungroup())}>Ungroup</button>
        <div class="ctx-sep"></div>
        <button data-testid="ctx-front" disabled={view.selectedCount === 0} onclick={() => runMenu(() => store.reorder("front"))}>Bring to front</button>
        <button data-testid="ctx-back" disabled={view.selectedCount === 0} onclick={() => runMenu(() => store.reorder("back"))}>Send to back</button>
        <div class="ctx-sep"></div>
        <button data-testid="ctx-selectall" onclick={() => runMenu(() => store.selectAll())}>Select all</button>
        <button data-testid="ctx-delete" disabled={view.selectedCount === 0} onclick={() => runMenu(() => store.deleteSelected())}>Delete</button>
      </div>
    {/if}
  </main>

  <div class="top-center">
    <div class="island toolbar" role="toolbar" aria-label="Drawing tools">
      {#each toolDefs as t (t.tool)}
        <button
          class="tool"
          data-testid={`tool-${t.tool}`}
          class:active={view.tool === t.tool}
          title={t.title}
          aria-label={t.title}
          onclick={() => pick(t.tool)}
        >
          <!-- eslint-disable-next-line svelte/no-at-html-tags — static icon strings -->
          {@html icons[t.tool]}
          <span class="badge">{t.badge}</span>
        </button>
      {/each}
      <span class="divider"></span>
      <button class="tool" data-testid="gen-image" title="Insert image — 9" aria-label="Insert image — 9" onclick={() => fileInput.click()}>
        {@html icons.image}
        <span class="badge">9</span>
      </button>
      <button
        class="tool"
        data-testid="more-tools"
        title="More tools"
        aria-label="More tools"
        aria-expanded={moreOpen}
        class:active={moreOpen || view.tool === "frame" || view.tool === "laser"}
        onclick={() => {
          moreOpen = !moreOpen;
        }}
      >
        {@html icons.shapes}
      </button>
      {#if moreOpen}
        <button
          type="button"
          class="menu-backdrop"
          aria-label="Close more tools"
          onclick={() => {
            moreOpen = false;
          }}
        ></button>
        <div class="island more-menu" data-testid="more-menu" role="menu">
          <button class="menu-item" data-testid="tool-frame" class:active={view.tool === "frame"} onclick={() => { pick("frame"); moreOpen = false; }}>
            <span class="mi-icon">{@html icons.frame}</span>Frame tool<kbd>F</kbd>
          </button>
          <button class="menu-item" data-testid="tool-laser" class:active={view.tool === "laser"} onclick={() => { pick("laser"); moreOpen = false; }}>
            <span class="mi-icon">{@html icons.laser}</span>Laser pointer<kbd>K</kbd>
          </button>
          <div class="menu-head">Generate</div>
          <button class="menu-item" data-testid="gen-note" onclick={() => { store.insertStickyNote(); moreOpen = false; }}>
            <span class="mi-icon">{@html icons.note}</span>Sticky note
          </button>
          <button class="menu-item" data-testid="gen-table" onclick={() => { store.insertTable(); moreOpen = false; }}>
            <span class="mi-icon">{@html icons.table}</span>Table
          </button>
          <button class="menu-item" data-testid="gen-chart" onclick={() => { store.insertChart([10, 20, 15, 30]); moreOpen = false; }}>
            <span class="mi-icon">{@html icons.chart}</span>Chart
          </button>
          <button class="menu-item" data-testid="gen-mermaid" onclick={() => { store.insertMermaid(mermaidSample); moreOpen = false; }}>
            <span class="mi-icon">{@html icons.mermaid}</span>Mermaid diagram
          </button>
        </div>
      {/if}
    </div>
    <p class="hint">
      To move canvas, hold <kbd>Middle mouse button</kbd> while dragging, or use the hand tool
    </p>
  </div>

  <input bind:this={fileInput} type="file" accept="image/*" hidden onchange={importImage} />

  {#if panelOpen && !panelExpanded}
    <button
      class="island tool panel-toggle"
      data-testid="panel-toggle"
      title="Show style panel"
      aria-label="Show style panel"
      onclick={() => {
        panelExpanded = true;
      }}
    >
      {@html icons.sliders}
    </button>
  {/if}
  {#if panelOpen && panelExpanded}
    <aside class="island panel">
      <header class="panel-head">
        <h3>Styles</h3>
        <button
          class="tool slim"
          data-testid="panel-collapse"
          title="Hide style panel"
          aria-label="Hide style panel"
          onclick={() => {
            panelExpanded = false;
          }}
        >
          {@html icons.chevronLeft}
        </button>
      </header>
      <section>
        <h4>Stroke</h4>
        <div class="row wrap">
          {#each STROKE_SWATCHES as c (c)}
            <button
              class="swatch"
              class:active={sel.strokeColor === c}
              style="--sw:{c}"
              title={c}
              aria-label={`Stroke ${c}`}
              onclick={() => store.setStrokeColor(c)}
            ></button>
          {/each}
          <input
            class="swatch-custom"
            type="color"
            value={sel.strokeColor.startsWith("#") ? sel.strokeColor.slice(0, 7) : "#1e1e1e"}
            oninput={(e) => store.setStrokeColor((e.currentTarget as HTMLInputElement).value)}
            aria-label="Custom stroke color"
            title="Custom colour"
          />
        </div>
      </section>
      <section>
        <h4>Background</h4>
        <div class="row wrap">
          {#each BG_SWATCHES as c (c)}
            <button
              class="swatch"
              class:transparent={c === "transparent"}
              class:active={sel.backgroundColor === c}
              style="--sw:{c === 'transparent' ? 'transparent' : c}"
              title={c}
              aria-label={`Background ${c}`}
              onclick={() => store.setBackgroundColor(c)}
            ></button>
          {/each}
          <input
            class="swatch-custom"
            type="color"
            value={sel.backgroundColor.startsWith("#") ? sel.backgroundColor.slice(0, 7) : "#ffec99"}
            oninput={(e) => store.setBackgroundColor((e.currentTarget as HTMLInputElement).value)}
            aria-label="Custom background color"
            title="Custom colour"
          />
        </div>
      </section>
      <section>
        <h4>Fill</h4>
        <select
          data-testid="fill-style"
          value={sel.fillStyle}
          onchange={(e) => store.setFillStyle((e.currentTarget as HTMLSelectElement).value as FillStyle)}
          aria-label="Fill style"
        >
          <option value="hachure">Hachure</option>
          <option value="cross-hatch">Cross-hatch</option>
          <option value="solid">Solid</option>
          <option value="zigzag">Zigzag</option>
        </select>
      </section>
      <section>
        <h4>Stroke width</h4>
        <div class="seg">
          {#each [{ w: 1, label: "Thin", glyph: "─" }, { w: 2, label: "Bold", glyph: "━" }, { w: 4, label: "Extra bold", glyph: "▬" }] as o (o.w)}
            <button class="seg-btn" data-testid={`stroke-width-${o.w}`} class:active={sel.strokeWidth === o.w} title={o.label} onclick={() => store.setStrokeWidth(o.w)}>{o.glyph}</button>
          {/each}
        </div>
      </section>
      <section>
        <h4>Stroke style</h4>
        <div class="seg">
          {#each [{ v: "solid", glyph: "—" }, { v: "dashed", glyph: "╌" }, { v: "dotted", glyph: "┈" }] as o (o.v)}
            <button class="seg-btn" data-testid={`stroke-style-${o.v}`} class:active={sel.strokeStyle === o.v} title={o.v} onclick={() => store.setStrokeStyle(o.v as StrokeStyle)}>{o.glyph}</button>
          {/each}
        </div>
      </section>
      <section>
        <h4>Sloppiness</h4>
        <div class="seg">
          {#each [{ r: 0, label: "Architect", glyph: "﹏" }, { r: 1, label: "Artist", glyph: "〰" }, { r: 2, label: "Cartoonist", glyph: "≈" }] as o (o.r)}
            <button class="seg-btn" data-testid={`sloppiness-${o.r}`} class:active={sel.roughness === o.r} title={o.label} onclick={() => store.setRoughness(o.r)}>{o.glyph}</button>
          {/each}
        </div>
      </section>
      <section>
        <h4>Edges</h4>
        <div class="seg">
          <button class="seg-btn" data-testid="edges-sharp" class:active={!sel.roundEdges} title="Sharp" onclick={() => store.setRoundEdges(false)}>⌐</button>
          <button class="seg-btn" data-testid="edges-round" class:active={sel.roundEdges} title="Round" onclick={() => store.setRoundEdges(true)}>◠</button>
        </div>
      </section>
      <section>
        <h4>Opacity</h4>
        <input
          data-testid="opacity"
          type="range"
          min="0"
          max="100"
          step="10"
          value={sel.opacity}
          oninput={(e) => store.setOpacity(Number((e.currentTarget as HTMLInputElement).value))}
          aria-label="Opacity"
        />
      </section>
      {#if sel.textContext}
        <section>
          <h4>Font family</h4>
          <div class="seg">
            {#each FONT_FAMILIES as f (f.id)}
              <button class="seg-btn" data-testid={`font-family-${f.label.toLowerCase()}`} class:active={sel.fontFamily === f.id} title={f.label} onclick={() => store.setFontFamily(f.id)}>{f.glyph}</button>
            {/each}
          </div>
        </section>
        <section>
          <h4>Font size</h4>
          <div class="seg">
            {#each FONT_SIZES as f (f.size)}
              <button class="seg-btn" data-testid={`font-size-${f.label.toLowerCase()}`} class:active={sel.fontSize === f.size} title={`${f.size}px`} onclick={() => store.setFontSize(f.size)}>{f.label}</button>
            {/each}
          </div>
        </section>
        <section>
          <h4>Text align</h4>
          <div class="seg">
            {#each [{ v: "left", glyph: "L" }, { v: "center", glyph: "C" }, { v: "right", glyph: "R" }] as o (o.v)}
              <button class="seg-btn" data-testid={`text-align-${o.v}`} class:active={sel.textAlign === o.v} title={o.v} onclick={() => store.setTextAlign(o.v as TextAlign)}>{o.glyph}</button>
            {/each}
          </div>
        </section>
      {/if}
      {#if sel.arrowContext}
        <section>
          <h4>Arrow type</h4>
          <div class="seg">
            {#each [{ v: "straight", glyph: "—" }, { v: "curved", glyph: "⌒" }, { v: "elbow", glyph: "⌐" }] as o (o.v)}
              <button class="seg-btn" data-testid={`arrow-type-${o.v}`} class:active={sel.arrowType === o.v} title={o.v} onclick={() => store.setArrowType(o.v as "straight" | "curved" | "elbow")}>{o.glyph}</button>
            {/each}
          </div>
        </section>
        <section>
          <h4>Arrowheads</h4>
          <div class="row">
            <label class="inline">Start
              <select
                data-testid="arrowhead-start"
                value={sel.startArrowhead ?? "none"}
                onchange={(e) => {
                  const v = (e.currentTarget as HTMLSelectElement).value;
                  store.setStartArrowhead(v === "none" ? null : (v as Arrowhead));
                }}
                aria-label="Start arrowhead"
              >
                {#each ARROWHEADS as h (h)}<option value={h}>{h}</option>{/each}
              </select>
            </label>
            <label class="inline">End
              <select
                data-testid="arrowhead-end"
                value={sel.endArrowhead ?? "none"}
                onchange={(e) => {
                  const v = (e.currentTarget as HTMLSelectElement).value;
                  store.setEndArrowhead(v === "none" ? null : (v as Arrowhead));
                }}
                aria-label="End arrowhead"
              >
                {#each ARROWHEADS as h (h)}<option value={h}>{h}</option>{/each}
              </select>
            </label>
          </div>
        </section>
      {/if}
      <section>
        <h4>Actions</h4>
        <div class="row wrap">
          <button class="chip" data-testid="delete" onclick={() => store.deleteSelected()}>Delete</button>
          <button class="chip" data-testid="duplicate" onclick={() => store.duplicate()}>Duplicate</button>
          <button class="chip" data-testid="group" onclick={() => store.group()}>Group</button>
          <button class="chip" onclick={() => store.ungroup()}>Ungroup</button>
        </div>
      </section>
      <section>
        <h4>Arrange</h4>
        <div class="row wrap">
          <button class="chip" title="Align left" onclick={() => store.align("left")}>⇤</button>
          <button class="chip" title="Align centre" onclick={() => store.align("centerX")}>↔</button>
          <button class="chip" title="Align right" onclick={() => store.align("right")}>⇥</button>
          <button class="chip" title="Flip horizontal" onclick={() => store.flip(true)}>⇋</button>
          <button class="chip" title="Bring to front" onclick={() => store.reorder("front")}>⤒</button>
          <button class="chip" title="Send to back" onclick={() => store.reorder("back")}>⤓</button>
        </div>
      </section>
      {#if view.table !== null}
        <section>
          <h4>Table</h4>
          <div class="row wrap">
            <button class="chip" data-testid="table-add-row" onclick={() => store.addTableRow()}>+ Row</button>
            <button class="chip" data-testid="table-add-col" onclick={() => store.addTableColumn()}>+ Col</button>
          </div>
        </section>
      {/if}
    </aside>
  {/if}

  <div class="bottom-left">
    <div class="island bar">
      <button class="tool slim" data-testid="zoom-out" title="Zoom out" onclick={() => store.zoomOut()}>−</button>
      <button class="zoom-reset" data-testid="zoom-reset" title="Reset zoom" onclick={() => store.resetZoom()}>{view.zoom}%</button>
      <button class="tool slim" data-testid="zoom-in" title="Zoom in" onclick={() => store.zoomIn()}>+</button>
    </div>
    <div class="island bar">
      <button class="tool slim" data-testid="undo" title="Undo" onclick={() => store.undo()} disabled={!view.canUndo}>↺</button>
      <button class="tool slim" data-testid="redo" title="Redo" onclick={() => store.redo()} disabled={!view.canRedo}>↻</button>
    </div>
    <span class="stats" data-testid="selection-stats">{view.stats ?? ""}</span>
  </div>

  <div class="bottom-right">
    {#if view.peers.length > 0}
      <span class="island bar peers" data-testid="peers">
        {#each view.peers as p (p.id)}
          <span class="peer" style="background:{p.color}" title={p.name}>{p.name}</span>
        {/each}
      </span>
    {/if}
    <div class="island bar">
      <button class="tool slim" data-testid="theme" title="Toggle theme" onclick={() => store.toggleTheme()}>{view.theme === "light" ? "🌙" : "☀️"}</button>
      <button class="chip" data-testid="export-svg" onclick={downloadSvg}>Export SVG</button>
      <button class="chip" data-testid="save" onclick={downloadJson}>Save</button>
    </div>
  </div>
</div>

<style>
  .app {
    position: absolute;
    inset: 0;
    overflow: hidden;
    --island: #ffffff;
    --ink: #1b1b1f;
    --muted: #8e8ea4;
    --border: #00000014;
    --hover: #f1f0ff;
    --active-bg: #e0dfff;
    --active-ink: #030064;
    --shadow: 0 0 0 1px var(--border), 0 7px 14px #0000000d, 0 2px 4px #00000014;
    color: var(--ink);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, sans-serif;
  }
  .app[data-theme="dark"] {
    --island: #232329;
    --ink: #e2e2e7;
    --muted: #8b8b9d;
    --border: #ffffff1a;
    --hover: #2e2d39;
    --active-bg: #403e6a;
    --active-ink: #e2dfff;
    --shadow: 0 0 0 1px var(--border), 0 7px 14px #00000059, 0 2px 4px #0000004d;
  }

  .stage { position: absolute; inset: 0; }

  .island {
    background: var(--island);
    border-radius: 10px;
    box-shadow: var(--shadow);
  }

  /* ── top toolbar island ─────────────────────────────────────────────── */
  .top-center {
    position: absolute;
    top: 16px;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    z-index: 4;
    pointer-events: none;
  }
  .top-center .island { pointer-events: auto; }
  .toolbar { position: relative; display: flex; align-items: center; gap: 2px; padding: 4px; }
  .menu-backdrop {
    position: fixed;
    inset: 0;
    z-index: 5;
    padding: 0;
    border: none;
    background: transparent;
    cursor: default;
  }
  .more-menu {
    position: absolute;
    top: calc(100% + 10px);
    right: 0;
    z-index: 6;
    display: flex;
    flex-direction: column;
    min-width: 200px;
    padding: 5px;
  }
  .menu-head {
    font-size: 11px;
    font-weight: 600;
    color: var(--muted);
    padding: 8px 10px 4px;
  }
  .menu-item {
    display: flex;
    align-items: center;
    gap: 10px;
    border: none;
    background: transparent;
    color: var(--ink);
    font-size: 13px;
    text-align: left;
    border-radius: 8px;
    padding: 7px 10px;
    cursor: pointer;
  }
  .menu-item:hover { background: var(--hover); }
  .menu-item.active { background: var(--active-bg); color: var(--active-ink); }
  .menu-item .mi-icon { display: grid; place-items: center; }
  .menu-item .mi-icon :global(svg) { width: 17px; height: 17px; }
  .menu-item kbd {
    margin-left: auto;
    font: 11px ui-monospace, Menlo, monospace;
    color: var(--muted);
  }
  .tool {
    position: relative;
    display: grid;
    place-items: center;
    width: 36px;
    height: 36px;
    padding: 0;
    border: none;
    border-radius: 8px;
    background: transparent;
    color: var(--ink);
    cursor: pointer;
  }
  .tool :global(svg) { width: 19px; height: 19px; }
  .tool:hover:not(:disabled) { background: var(--hover); }
  .tool.active { background: var(--active-bg); color: var(--active-ink); }
  .tool:disabled { opacity: 0.35; cursor: default; }
  .tool .badge {
    position: absolute;
    right: 3px;
    bottom: 1px;
    font-size: 9px;
    color: var(--muted);
  }
  .tool.active .badge { color: var(--active-ink); opacity: 0.7; }
  .divider { width: 1px; height: 22px; background: var(--border); margin: 0 4px; }
  .hint { margin: 0; font-size: 12px; color: var(--muted); user-select: none; }
  .hint kbd {
    font: 11px ui-monospace, Menlo, monospace;
    padding: 1px 5px;
    border: 1px solid var(--border);
    border-bottom-width: 2px;
    border-radius: 4px;
  }

  /* ── contextual style panel (left) ──────────────────────────────────── */
  .panel-toggle {
    position: absolute;
    top: 80px;
    left: 16px;
    z-index: 3;
  }
  .panel-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin: -2px 0 -4px;
  }
  .panel-head h3 {
    margin: 0;
    font-size: 12.5px;
    font-weight: 600;
  }
  .panel {
    position: absolute;
    top: 80px;
    left: 16px;
    width: 232px;
    max-height: calc(100% - 160px);
    overflow-y: auto;
    padding: 12px 14px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    z-index: 3;
  }
  .panel h4 {
    margin: 0 0 6px;
    font-size: 11px;
    font-weight: 600;
    color: var(--muted);
  }
  .row { display: flex; align-items: center; gap: 8px; }
  .swatch {
    width: 22px;
    height: 22px;
    padding: 0;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: var(--sw);
    cursor: pointer;
  }
  .swatch.transparent {
    background: repeating-conic-gradient(#d0d0d8 0% 25%, #ffffff 0% 50%) 0 0 / 10px 10px;
  }
  .swatch.active {
    outline: 2px solid var(--active-ink);
    outline-offset: 1px;
  }
  .swatch-custom {
    width: 22px;
    height: 22px;
    padding: 0;
    border: 1px dashed var(--muted);
    border-radius: 6px;
    background: transparent;
    cursor: pointer;
  }
  .seg { display: flex; gap: 3px; flex-wrap: wrap; }
  .seg-btn {
    min-width: 30px;
    height: 28px;
    padding: 0 7px;
    border: 1px solid var(--border);
    border-radius: 7px;
    background: transparent;
    color: var(--ink);
    font-size: 13px;
    cursor: pointer;
  }
  .seg-btn:hover { background: var(--hover); }
  .seg-btn.active {
    background: var(--active-bg);
    color: var(--active-ink);
    border-color: transparent;
  }
  .row.wrap { flex-wrap: wrap; }
  .panel input[type="color"] {
    width: 26px;
    height: 26px;
    padding: 0;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: transparent;
    cursor: pointer;
  }
  .panel input[type="range"] { width: 110px; }
  .panel select {
    background: var(--island);
    color: var(--ink);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 3px 6px;
    font-size: 12px;
  }
  label.inline {
    display: inline-flex;
    gap: 6px;
    align-items: center;
    font-size: 12.5px;
  }

  /* ── chips (small text buttons) ─────────────────────────────────────── */
  .chip {
    padding: 5px 9px;
    font-size: 12.5px;
    border: none;
    border-radius: 8px;
    background: transparent;
    color: var(--ink);
    cursor: pointer;
  }
  .chip:hover:not(:disabled) { background: var(--hover); }
  .chip:disabled { opacity: 0.35; cursor: default; }

  /* ── bottom islands ─────────────────────────────────────────────────── */
  .bottom-left,
  .bottom-right {
    position: absolute;
    bottom: 16px;
    display: flex;
    align-items: center;
    gap: 10px;
    z-index: 4;
  }
  .bottom-left { left: 16px; }
  .bottom-right { right: 16px; }
  .bar { display: flex; align-items: center; gap: 2px; padding: 3px; }
  .tool.slim { width: 30px; height: 30px; font-size: 15px; }
  .zoom-reset {
    min-width: 52px;
    padding: 5px 6px;
    font-size: 12.5px;
    font-variant-numeric: tabular-nums;
    border: none;
    border-radius: 8px;
    background: transparent;
    color: var(--ink);
    cursor: pointer;
  }
  .zoom-reset:hover { background: var(--hover); }
  .stats { font-size: 12px; color: var(--muted); font-variant-numeric: tabular-nums; }

  .peers { padding: 5px 8px; display: inline-flex; gap: 4px; }
  .peer { color: #fff; font-size: 11px; padding: 2px 8px; border-radius: 10px; }

  /* ── on-canvas editors & context menu ───────────────────────────────── */
  .text-editor {
    position: absolute;
    box-sizing: border-box;
    min-width: 120px;
    min-height: 28px;
    /* Match the canvas's default hand-drawn text face so editing is WYSIWYG.
       line-height 25px = fontSize 20 × the model's 1.25 line height; the
       centred editor's padding math keys on it. */
    font: 20px / 25px "Excalifont", "Virgil", "Bradley Hand", "Comic Sans MS", "Segoe Print", cursive;
    border: 1px dashed #6965db;
    background: transparent;
    color: inherit;
    resize: none;
    outline: none;
    padding: 0;
  }
  .text-editor.centered {
    text-align: center;
    overflow: hidden;
  }
  .chart-editor {
    position: absolute;
    display: flex;
    gap: 8px;
    align-items: center;
    padding: 8px 10px;
    z-index: 10;
  }
  .chart-editor input[type="text"] {
    width: 140px;
    background: var(--island);
    color: var(--ink);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 3px 6px;
  }
  .chart-editor select {
    background: var(--island);
    color: var(--ink);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 3px 6px;
  }
  .ctx-backdrop {
    position: fixed;
    inset: 0;
    z-index: 20;
    padding: 0;
    border: none;
    border-radius: 0;
    background: transparent;
    cursor: default;
  }
  .context-menu {
    position: absolute;
    z-index: 21;
    display: flex;
    flex-direction: column;
    min-width: 160px;
    padding: 4px;
  }
  .context-menu button {
    border: none;
    background: transparent;
    color: var(--ink);
    text-align: left;
    font-size: 13px;
    border-radius: 6px;
    padding: 6px 10px;
    cursor: pointer;
  }
  .context-menu button:not(:disabled):hover { background: var(--hover); }
  .context-menu button:disabled { opacity: 0.4; cursor: default; }
  .ctx-sep { height: 1px; margin: 4px 6px; background: var(--border); }
</style>
