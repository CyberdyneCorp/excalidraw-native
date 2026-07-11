## 1. Store & renderer wiring

- [x] 1.1 Store: `snapEnabled`/`gridEnabled` getters + toggles, `contentOffscreen` derivation, `scrollToContent()` (reuses `zoomToFit`), and a `canQuickCreate` guard (exactly one bindable shape selected)
- [x] 1.2 `Canvas.svelte`: pass `gridSize` to `renderScene` while the grid is enabled
- [x] 1.3 Unit tests: quick-create guard, contentOffscreen true/false, grid/snap toggles

## 2. Flowchart quick-create & recognition

- [x] 2.1 `Cmd/Ctrl + ↑↓←→` spawns a connected node via `store.addFlowchartNode(direction)` (inert while editing text; ignored unless `canQuickCreate`)
- [x] 2.2 Quick-arrow buttons: four DOM buttons around a single selected bindable shape, hidden during drags/edits; click spawns in that direction
- [x] 2.3 "Snap to shape" context-menu action for a selected freedraw (`store.recognizeSelectedStroke()`), no-op when nothing is recognized

## 3. Canvas helpers, zen mode, palette

- [x] 3.1 Zoom-to-fit shortcut (`Shift+1`) and zoom-island button; scroll-back-to-content pill (shown per `contentOffscreen`, recentres on click)
- [x] 3.2 Grid and snap toggles in the zoom island (state visible)
- [x] 3.3 Zen mode (`Alt+Z`): hide all chrome but the canvas + zoom island
- [x] 3.4 Command palette (`Cmd/Ctrl+K`): searchable list of tools/generators/view/edit/file commands reusing the existing handlers; type-to-filter, Up/Down/Enter/Escape

## 4. Verification

- [x] 4.1 E2E: keyboard quick-create builds a connected node (arrow bound both ends); quick-arrow button spawns downward
- [x] 4.2 E2E: snap-to-shape converts a rough freedraw loop to a rectangle (+ undo); grid/snap toggles apply
- [x] 4.3 E2E: zoom-to-fit; scroll-back pill appears when content is off-screen and recentres; zen mode hides/restores chrome
- [x] 4.4 E2E: palette opens with Cmd+K, filters on "rect", Enter activates the rectangle tool, Escape closes

## 5. Docs & spec sync

- [ ] 5.1 Update `web/README.md` + `docs/WEB_PARITY_ROADMAP.md`
- [x] 5.2 `openspec validate` clean; archive after merge
