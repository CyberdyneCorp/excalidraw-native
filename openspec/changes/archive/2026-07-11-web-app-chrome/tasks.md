## 1. Core & store

- [x] 1.1 `RenderOptions.background?: string | "transparent"` override in `renderScene` (+ unit test: transparent pass paints no background, normal pass unchanged)
- [x] 1.2 Store passthroughs: `toolLocked` getter + `toggleToolLock()`, `resetScene()` (undoable), `openPngScene(bytes)` via `containsScene`/`extractScene` returning success (+ unit tests incl. PNG round-trip through the store)

## 2. Export pipeline

- [x] 2.1 `apps/web/src/lib/export-image.ts`: content/selection bounds → offscreen canvas at scale → `renderScene` (light theme, background override) → PNG bytes → optional `embedScene`; SVG path with selection subset + optional background
- [x] 2.2 Export dialog UI: format, scale (PNG), background, selection-only (gated on selection), embed scene (PNG, default on); wired to downloads

## 3. Chrome UI

- [x] 3.1 Toolbar tool-lock toggle (testid `tool-lock`), lock state visible; store-driven
- [x] 3.2 App menu island (testid `app-menu`): Open…, Save, Export image…, Reset canvas, theme, Help; file input accepting `.excalidraw` + `.png`; PNG-without-scene rejection message
- [x] 3.3 Welcome overlay (pointer-transparent, shown per D5) and Help overlay (`?` key + menu, shortcut map, Escape/outside dismiss)

## 4. Verification

- [x] 4.1 E2E: tool lock draws twice without re-picking; menu Save download fires; Open restores a saved `.excalidraw`; Reset canvas + undo
- [x] 4.2 E2E: export dialog → PNG download event; byte-level PNG embed round-trip in-page (export bytes → extractScene → same element count); transparent + selection-only options drive the helper
- [x] 4.3 E2E: welcome shows on empty canvas, hides on tool pick / element; help opens with `?`, lists tool shortcuts, closes with Escape

## 5. Docs & spec sync

- [x] 5.1 Update `web/README.md` + `docs/WEB_PARITY_ROADMAP.md` Phase 3 status
- [x] 5.2 `openspec validate` clean; archive after merge
