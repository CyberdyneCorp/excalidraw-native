## 1. Core: styles & frames

- [x] 1.1 `EditorController.styleOf(id): ElementStyle` (stroke/background/fill/width/style/roughness/roundness/opacity + font & arrowhead properties where applicable)
- [x] 1.2 `EditorController.applyStyle(style)` — one transaction over the selection, skipping properties that don't apply per element type
- [x] 1.3 `EditorController.wrapSelectionInFrame()` — frame from selection bounds + margin, inserted below the selection, children adopted via `reassignFrameMembership`, frame selected; one undo step
- [x] 1.4 Unit tests: style capture/apply across mixed types + single undo; wrap-in-frame adopts children and undoes cleanly

## 2. Store: clipboard passthroughs

- [x] 2.1 `copySelection(): string | null`, `cutSelection(): string | null` (copy + delete, one undo step), `pasteJSON(json, scenePoint?)` centring the paste at a scene point
- [x] 2.2 `pasteImage(dataURL, mime, w, h, scenePoint?)` and `pasteText(text, scenePoint?)` for external clipboard content; track the last pointer scene position for paste placement
- [x] 2.3 `copyStyles()` / `pasteStyles()` + `hasCopiedStyles` (app-state style buffer)
- [x] 2.4 Unit tests: copy→paste creates distinct offset elements; cut undo; paste at a point; styles copy/paste

## 3. App: clipboard bridge & menus

- [x] 3.1 `copy`/`cut`/`paste` window listeners (payload → `.excalidraw` text; paste order: our payload → image file → plain text), inert while a text editor is open; ⌘X/⌘C/⌘V shortcuts
- [x] 3.2 Menu clipboard actions via the async Clipboard API (`writeText`, `readText`) and copy-as-PNG via `ClipboardItem` (capability-guarded), reusing `lib/export-image.ts`; copy-as-SVG as text
- [x] 3.3 Element context menu: full command set (cut/copy/paste, copy as PNG/SVG, copy/paste styles, wrap in frame, duplicate, group/ungroup, 4-step z-order, flip H/V, add link, lock, select all, delete) with correct gating
- [x] 3.4 Empty-canvas context menu: paste, select all, zoom to fit

## 4. Verification

- [x] 4.1 E2E (clipboard permissions granted): copy→paste round-trip, cut+undo, paste plain text, paste an image
- [x] 4.2 E2E: copy styles → paste styles across shapes (+ undo); wrap selection in frame moves children
- [x] 4.3 E2E: 4-step z-order via the menu; empty-canvas menu offers paste/select-all/zoom-to-fit; existing menu tests still pass

## 5. Docs & spec sync

- [x] 5.1 Update `web/README.md` + `docs/WEB_PARITY_ROADMAP.md` (Phase 2 complete)
- [x] 5.2 `openspec validate` clean; archive after merge
