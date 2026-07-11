# Design — Web Smart Canvas & Polish

## Context

The core already implements the smart behaviour: `addFlowchartNode(id, dir)`
(spawn + bind + place), `recognizeFreedraw(id)` (ShapeRecognizer →
replacement element), `snapEnabled` (object/gap snapping in the drag path),
and the renderer takes `gridSize`. The store even exposes
`addFlowchartNode(direction)` and `recognizeSelectedStroke()` — nothing in
the UI calls them. `zoomToFit` landed with the clipboard change. This is
almost entirely host wiring plus one new component (the palette).

## Goals / Non-Goals

**Goals:** flowchart quick-create (keyboard + hover buttons), snap-to-shape,
zoom-to-fit / scroll-back-to-content / grid / snap, zen mode, command
palette.

**Non-Goals:** the library panel and share dialog (`web-library-and-share`);
AI features (text-to-diagram, wireframe-to-code); laser-pointer trails
(already shipped); mobile/touch-specific gestures.

## Decisions

**D1 — Quick-arrow buttons are DOM, not canvas.** They are four small
buttons positioned over the canvas from the selection's view bounds
(`selectionBounds` → `sceneToView`), shown only when exactly one bindable
shape is selected and no drag/edit is in flight. Keeping them in the DOM
gets hit-testing, hover states, and accessibility for free, and keeps the
renderer free of interactive chrome.

**D2 — `Cmd/Ctrl+arrow` is the keyboard path** (excalidraw's binding), guarded
by the existing "inert while editing text" rule and ignored when the
selection isn't a single bindable shape.

**D3 — Grid/snap/zen are host state, not scene state.** Grid size is passed
to `renderScene` only while enabled (the renderer already draws it);
`snapEnabled` toggles the controller flag; `zenMode` already exists on the
store. None of it is serialized — a grid preference is not part of the
document (excalidraw stores it in appState; we keep it host-local until a
persistence change needs it).

**D4 — Scroll-back pill visibility is derived, not tracked.** `contentOffscreen`
= scene has elements AND `commonBounds(visibleElements)` does not intersect
the current viewport rect. Clicking the pill calls `zoomToFit()`.

**D5 — The palette is a filtered command list, not a fuzzy matcher.** A
simple case-insensitive substring match over `{ id, label, keywords, run }`
entries is enough for ~30 commands and keeps the code trivially testable;
commands reuse the exact handlers the menus call (one source of truth).

## Risks / Trade-offs

- [Quick-arrow buttons could obscure small shapes] → they sit just outside the
  selection bounds with an 8px gap, and hide during drags/edits.
- [Palette + text editor keybinding clash] → the palette never opens while a
  text editor is focused (same guard as the tool shortcuts).
- [Recognition may return null on ambiguous strokes] → the action is a no-op
  then; the spec states the stroke is left unchanged.

## Migration Plan

No data or protocol changes; one PR (stacked with the clipboard change).

## Open Questions

- Whether grid/snap/zen should persist across reloads (localStorage) — left
  out for now; a future persistence change can adopt them together with
  autosave.
