# Web Smart Canvas & Polish

## Why

Phase 4 (part 1) of the excalidraw.com parity roadmap. The editor core
already implements the smart features — `addFlowchartNode(id, direction)`
spawns a connected node, `recognizeFreedraw(id)` snaps a rough sketch to a
real shape, `snapEnabled` drives object snapping, the renderer takes a
`gridSize`, `zenMode` exists on the store — but none of them are reachable
from the UI. The web client also lacks the navigation helpers that make a
big canvas usable (zoom-to-fit shortcut, scroll-back-to-content) and the
command palette.

## What Changes

- **Flowchart quick-create** — with a shape selected, `Cmd/Ctrl + ↑↓←→`
  spawns a connected node in that direction (existing `addFlowchartNode`);
  hovering a selected shape shows four quick-arrow buttons (one per side)
  that do the same with one click.
- **Shape recognition** — a "Snap to shape" action for a selected freedraw
  stroke (existing `recognizeFreedraw`), also offered in the context menu.
- **Canvas helpers** — zoom-to-fit shortcut (`Shift+1`), a
  **scroll-back-to-content** pill shown when the content is off-screen, and
  grid + snap toggles (renderer already draws the grid).
- **Zen mode** (`Alt+Z`) — hide all chrome except the canvas and the
  bottom-left zoom island.
- **Command palette** (`Cmd/Ctrl+K`) — fuzzy-searchable list of tools and
  actions (tools, generators, view toggles, file flows, edit commands),
  keyboard-navigable, executing the same handlers as the menus.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `web-client`: new host requirements — flowchart quick-create (keyboard +
  hover buttons), shape recognition action, canvas helpers (zoom-to-fit,
  scroll-back-to-content, grid/snap toggles), zen mode, command palette.

## Impact

- `web/packages/excalidraw-svelte`: store passthroughs (`snapEnabled`/
  `gridEnabled` state, `contentOffscreen` derivation, `scrollToContent()`,
  `recognizeSelectedStroke` already exists); renderer grid already supported.
- `web/apps/web`: `App.svelte` (palette, zen mode, pill, toggles, quick-arrow
  overlay buttons), `Canvas.svelte` (pass `gridSize` when enabled).
- E2E: quick-create by keyboard and by button, snap-to-shape, zoom-to-fit,
  scroll-back pill, grid/snap toggles, zen mode, command palette.
- No schema, file-format, or protocol changes — every action writes standard
  elements; iOS/Android untouched.
