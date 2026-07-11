# Web client parity roadmap (vs excalidraw.com)

Status: proposed · 2026-07-10
Scope: `web/` Svelte client (`web/apps/web` + `@cyberdynecorp/excalidraw-svelte`)

## How this was produced

Both apps were driven through the same nine scenarios with Playwright (Chromium,
1280×800): draw a rectangle, double-click to label it, hover/draw/rebind arrows,
move a bound shape, select and style, right-click, add canvas text, toggle theme.
Screenshots were captured per step and the local editor store was probed via
`window.__store` for ground truth.

Key probe results:

- Double-click on a shape leaves `editingText = null` — no label editor opens.
  The keystrokes then leak into single-letter tool shortcuts ("Hello" ends with
  the Ellipse tool active).
- A drawn arrow between two shapes **does** get real `startBinding`/`endBinding`
  (orbit fixed-point on both ends), and moving the bound shape **does** reroute
  the arrow. The binding engine is at parity; the affordances are not.
- Double-click on empty canvas creates nothing (excalidraw.com creates a text
  element in place).
- Dark theme only darkens the chrome: element strokes stay near-black and are
  effectively invisible on the dark canvas. excalidraw.com inverts element
  colors per theme.

## Gap summary

| Layer | Missing vs excalidraw.com | Severity |
|---|---|---|
| Canvas interactions | Double-click-to-label on shapes; canvas text on double-click; arrow-tool hover highlight/snap; typing leaking into tool shortcuts | P0 — blocks everyday drawing |
| Editing surface | Contextual properties panel (swatches, stroke style, sloppiness, edges, opacity, fonts, arrow type, layers); fuller context menu; dark-theme element inversion | P1 — visible on every selection |
| App chrome & flows | Icon toolbar + shortcut badges + hint line, tool lock, menu (open/save/export dialog), welcome screen, library, help overlay, share UI | P2 — polish & discoverability |

## Phase 1 — Core canvas interactions (P0) — ✅ implemented

Implemented via the `web-canvas-interaction-parity` OpenSpec change
(2026-07-10): all four items below plus the typing guard, with unit, interop
(relay + Yjs), and Playwright e2e coverage. Dark-theme element inversion was
pulled forward from Phase 2 into the same change.

All model plumbing already existed (bound text works for sticky notes/tables;
bindings work for arrows). This was host/controller wiring.

1. **Bound labels on shapes.** Double-clicking a rectangle/diamond/ellipse
   creates (or edits, if present) a centered, wrapping bound text; Enter on a
   selected container opens its label. Extend `EditorStore.doubleClickAt` to a
   create-if-missing step in front of the existing `beginBoundTextEdit` path.
2. **Text on empty canvas.** Double-click on empty canvas opens a new text
   element editor in place (same editor the text tool uses).
3. **Arrow binding affordances.** With the arrow tool active or an endpoint
   being dragged: highlight the bindable shape under the cursor in the overlay,
   snap endpoints to the shape outline, and allow starting/ending anywhere on
   or near a shape (excalidraw's blue highlight ring behavior).
4. **Typing guard.** Single-letter tool shortcuts must never fire while a text
   editor is open/focused; audit all `onKeydown` paths in `App.svelte`.

## Phase 2 — Editing surface (P1) — ✅ complete

1. **Dark-theme element inversion** — ✅ done early, shipped with Phase 1
   (`themeColor` paint-time mapping in the renderer).
2. **Contextual properties panel** — ✅ implemented via the
   `web-style-panel-parity` change (2026-07-10): swatch palettes for
   stroke/background, stroke width presets, stroke style, sloppiness, edges,
   opacity, font family/size/align, arrow type (straight/curved/elbow) +
   arrowheads; sections shown per selection/tool, controls reflect the
   selection.
3. **Context menu parity** — ✅ implemented via the
   `web-context-menu-clipboard` change (2026-07-11): system-clipboard
   cut/copy/paste (incl. external images and text), copy as PNG/SVG,
   copy/paste styles, wrap in frame, flip H/V, 4-step z-order, lock, add
   link; distinct empty-canvas menu (paste, select all, zoom to fit).

## Phase 3 — App chrome & flows (P2) — ✅ implemented

Shipped via the `web-app-chrome` change (2026-07-11): tool lock, app menu
(open/save/export/reset/theme/help), export-image dialog (PNG/SVG, scale,
background, selection-only, embed), PNG scene-embed round-trip, welcome
screen, and the help overlay. The icon toolbar + shortcut badges + hint line
landed earlier with Phase 1.


1. **Icon toolbar** with shortcut number badges, contextual hint line under the
   toolbar, and tool lock ("keep tool active").
2. **Menu & welcome screen** — hamburger menu with open/save, export-image
   dialog (PNG/SVG, scale, background, selection-only), reset canvas, theme;
   first-run welcome overlay.
3. **PNG export with embedded scene** — round-trip parity with the iOS
   `persistence` capability.
4. **Help overlay** (`?`) with the shortcut map.

## Phase 4 — Smart features & polish (P3)

1. **Flowchart quick-create** — ✅ implemented (`web-smart-canvas`, 2026-07-11):
   Cmd/Ctrl+arrow spawning and hover quick-arrow buttons.
2. **Canvas helpers** — ✅ implemented (`web-smart-canvas`): zoom-to-fit,
   scroll-back-to-content pill, grid + snap toggles (the grid was declared in
   `RenderOptions` but never drawn — now implemented), zen mode, command
   palette, plus freehand shape recognition ("Snap to shape").
3. **Library panel** — `.excalidrawlib` import/insert (`file-format` spec).
4. **Share/collab UI** — a dialog around the existing relay/Yjs collab so
   rooms aren't URL-parameter-only.

## Process

Each phase lands as one OpenSpec change (or a small set) against the
`web-client` spec, referencing the relevant capability specs
(`drawing-tools`, `arrows-and-bindings`, `platform-ux`, `persistence`,
`smart-features`). Every behavior change ships with a Playwright e2e in
`web/apps/web/e2e/` mirroring the scenarios used for this audit.
