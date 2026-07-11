# Web App Chrome & Flows

## Why

Phase 3 of the excalidraw.com parity roadmap: the web client still looks like
a test harness around the canvas — no way to open a file, no export dialog
(SVG-only download), no tool lock, no welcome screen, no help. The editor
core already has everything the flows need (`toolLocked` honoured by both
creation paths, the PNG scene-embed codec with tests, `loadDocument`), so
this is host wiring and UI.

## What Changes

- **Tool lock** — a toolbar lock toggle ("keep tool active"): with lock on,
  drawing does not revert to the selection tool (existing `toolLocked` core
  behaviour, currently unreachable from the UI).
- **Hamburger menu** (top-left island): Open… (`.excalidraw` files and PNGs
  with an embedded scene), Save (.excalidraw download), Export image…,
  Reset canvas (undoable), theme toggle, Help.
- **Export image dialog** — PNG or SVG; scale 1×/2×/3× (PNG); background
  on/off (off = transparent PNG / no SVG background); selection-only;
  "embed scene" (PNG) so the exported file reopens as an editable document.
- **PNG scene-embed round-trip** — Export with embed → Open the PNG →
  identical scene (web parity with the iOS `persistence` capability).
- **Welcome screen** — a first-run overlay (hints + shortcuts pointer) shown
  over an empty canvas, dismissed by drawing or picking a tool.
- **Help overlay** — the keyboard-shortcut map, opened with `?` or from the
  menu, dismissed with Escape/outside click.
- Renderer: an optional background override for exports (transparent or a
  fixed colour) — paint-time only, no model change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `web-client`: new host requirements — tool lock, app menu with file
  open/save, export-image dialog, PNG scene-embed round-trip via Open,
  welcome screen, help overlay.
- `scene-rendering`: ADDED requirement — render-time background override for
  exports (transparent/custom), leaving on-canvas rendering untouched.

## Impact

- `web/apps/web`: `App.svelte` (menu, dialogs, welcome, lock button), a small
  `lib/export-image.ts` (offscreen-canvas PNG rasterization + `embedScene`,
  SVG selection subset), file-open input handling.
- `web/packages/excalidraw-svelte`: `RenderOptions.background` override;
  store passthroughs (`toolLocked` toggle, `resetScene`, PNG-aware
  `openFile`); unit tests.
- E2E: menu flows, export downloads, `.excalidraw`/PNG open, tool lock,
  welcome + help overlays.
- No schema, file-format, or protocol changes (the PNG embed uses the
  existing excalidraw-compatible `tEXt` chunk codec); iOS/Android untouched.
