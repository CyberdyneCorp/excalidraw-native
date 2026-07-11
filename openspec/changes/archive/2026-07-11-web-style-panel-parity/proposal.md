# Web Style Panel Parity

## Why

Phase 2 of the excalidraw.com parity roadmap (`docs/WEB_PARITY_ROADMAP.md`):
the web client's style panel exposes only five controls (two raw colour
inputs, fill pattern, a width slider, an elbow checkbox) while the editor
core already implements most of excalidraw's style model (`setStrokeStyle`,
`setOpacity`, `setRoughness`, `setRoundEdges`, `updateSelectedText`, …).
Users coming from excalidraw.com miss swatch palettes, stroke styles,
sloppiness, edges, opacity, font controls, and arrow options — the single
most visible remaining difference after Phase 1.

## What Changes

- Rebuild the left style panel to excalidraw's control set, wired to the
  existing store APIs: stroke/background **swatch palettes** (excalidraw's
  preset colours + a custom picker), stroke **width presets**
  (thin/bold/extra-bold), **stroke style** (solid/dashed/dotted),
  **sloppiness** (architect/artist/cartoonist), **edges** (sharp/round),
  **opacity** slider, and the existing fill pattern.
- **Text section** (shown for text selections/tool): font family
  (hand-drawn/normal/code), font size (S/M/L/XL), text alignment.
- **Arrow section** (shown for arrow/line selections/tool): arrow type
  (straight/curved/elbow) and start/end **arrowhead pickers** (none, arrow,
  triangle, bar, dot, diamond — the common excalidraw subset of the model's
  full `Arrowhead` vocabulary).
- Sections render contextually per selection/tool; controls reflect the
  current selection's values (or the defaults for the next element when
  nothing is selected) and write through to both.
- Small core additions where a setter is missing: start/end arrowhead
  setters and an arrow-type setter (straight/curved/elbow mapping to
  `roundness`/`elbowed`); font family/size/align convenience wrappers over
  `updateSelectedText`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `web-client`: new host requirements for the style panel's control set,
  contextual sections, and selection-reflecting behaviour.

## Impact

- `web/apps/web/src/App.svelte`: panel markup/CSS (swatch rows, segmented
  controls, sliders, contextual sections).
- `web/packages/excalidraw-svelte`: `EditorStore` setters for arrowheads,
  arrow type, and font properties (thin wrappers over existing controller
  commands); unit tests.
- E2E: panel-driven style assertions in `web/apps/web/e2e/`.
- No schema, file-format, or collaboration-protocol changes — every control
  writes standard element fields that already round-trip and sync; iOS and
  Android are untouched.
