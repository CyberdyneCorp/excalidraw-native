## 1. Store setters (thin wrappers, unit tested)

- [x] 1.1 `setStartArrowhead` / `setEndArrowhead` (apply to selected linear elements + currentItem defaults)
- [x] 1.2 `setArrowType("straight" | "curved" | "elbow")` mapping to `elbowed`/`roundness` per design D2 (replaces the bare elbow toggle)
- [x] 1.3 `setFontFamily` / `setFontSize` / `setTextAlign` wrappers over `updateSelectedText` + currentItem defaults
- [x] 1.4 Unit tests: each setter updates a selected element and the next-created element; arrow-type mapping round-trips all three types

## 2. Panel UI

- [x] 2.1 Stroke & background swatch rows (excalidraw preset palettes + custom colour input), active-swatch state
- [x] 2.2 Segmented controls: stroke width presets, stroke style, sloppiness, edges; opacity slider; keep fill pattern
- [x] 2.3 Contextual text section (family/size/align) and arrow section (type + start/end arrowheads), gated per selection/tool
- [x] 2.4 Selection reflection: derive active control states from the first selected element, falling back to currentItem defaults

## 3. Verification

- [x] 3.1 E2E: style a selected shape (dashed + cartoonist + 50% opacity) and assert element fields + repaint
- [x] 3.2 E2E: swatch with empty selection styles the next drawn element; panel reflects a selected element's values
- [x] 3.3 E2E: text section (size L + centre) and arrow section (triangle start / none end, arrow-type switch) drive the store correctly
- [x] 3.4 Save/reload round-trip keeps all panel-set fields (documentJSON assertions)

## 4. Docs & spec sync

- [x] 4.1 Update `web/README.md` notes and `docs/WEB_PARITY_ROADMAP.md` Phase 2 status
- [x] 4.2 `openspec validate` clean; archive after merge
