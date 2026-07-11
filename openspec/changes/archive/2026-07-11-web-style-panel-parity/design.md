# Design — Web Style Panel Parity

## Context

Phase 1 delivered the excalidraw-style chrome with a collapsible left panel,
but the panel exposes only five controls. The editor core already implements
most of the style model the panel needs: `setStrokeColor`, `setBackgroundColor`,
`setFillStyle`, `setStrokeWidth`, `setStrokeStyle`, `setOpacity`,
`setRoughness`, `setRoundEdges`, `setElbowed`, and `updateSelectedText`
(arbitrary text-property edits with size recomputation). The model's
`Arrowhead` type already carries excalidraw's full vocabulary, and `roundness`
/ `elbowed` express the three arrow types. This change is therefore ~80% panel
UI over existing APIs, plus a handful of thin store setters.

## Goals / Non-Goals

**Goals:**

- Excalidraw-parity control set in the panel, contextually sectioned, applying
  to the selection and to subsequent elements, and reflecting the selection.
- Small store additions: `setStartArrowhead`, `setEndArrowhead`,
  `setArrowType("straight" | "curved" | "elbow")`, `setFontFamily`,
  `setFontSize`, `setTextAlign` (wrappers over existing controller commands).
- Unit tests for every new setter; e2e driving the panel against the real app.

**Non-Goals:**

- Context-menu parity and clipboard (`web-context-menu-clipboard`, next).
- Custom color mixing UI beyond a native picker; palette management.
- The full arrowhead vocabulary in the picker (model supports it; the picker
  shows excalidraw's common six — none/arrow/triangle/bar/dot/diamond).
- iOS/Android work — shared fields only, no schema or protocol changes.

## Decisions

**D1 — Swatches use excalidraw's preset palettes.** Stroke:
`#1e1e1e, #e03131, #2f9e44, #1971c2, #f08c00`; background:
`transparent, #ffc9c9, #b2f2bb, #a5d8ff, #ffec99`; plus a native
`<input type="color">` as the custom picker. Presets keep files
visually identical when opened on excalidraw.com.
*Alternative:* a full colour-picker popover like excalidraw's — deferred;
the native input covers custom colours at a fraction of the UI cost.

**D2 — Arrow type maps onto existing fields.** `straight` → `elbowed: false,
roundness: null`; `curved` → `elbowed: false, roundness: { type: 2 }`;
`elbow` → `elbowed: true`. No new model fields; the elbow checkbox is
replaced by the three-way control.

**D3 — Selection reflection is derived, not stored.** The panel derives its
active states from the first selected element (falling back to
`controller.currentItem`) inside the existing `view` `$derived` block —
no new state to keep in sync, and the 40ms revision poll keeps it live.

**D4 — Font size presets S/M/L/XL = 16/20/28/36** (excalidraw's mapping);
font families map to the model's `FontFamily` ids already used by the
renderer's CSS stacks.

## Risks / Trade-offs

- [Segmented controls crowd the 208px panel] → group as icon-button rows
  (excalidraw's own layout); widen the panel to ~230px if needed.
- [Reflecting multi-selections is ambiguous] → first-selected-element rule,
  stated in the spec; matches excalidraw's behaviour closely enough.
- [Arrowhead rendering covers only some heads visually] → the renderer draws
  triangle/diamond filled and the rest as open V/bar/dot approximations;
  visual fidelity gaps are renderer follow-ups, the fields round-trip
  regardless.

## Migration Plan

No data or protocol changes; ship as one PR. The elbow checkbox is replaced
by the arrow-type control (same underlying field — no stored-data impact).

## Open Questions

- Whether to keep the Arrange/Actions sections in the panel or move them to
  the context menu once `web-context-menu-clipboard` lands (leaning: keep
  both, like excalidraw).
