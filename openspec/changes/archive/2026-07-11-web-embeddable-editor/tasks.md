## 1. Packaging

- [x] 1.1 Add `@sveltejs/package` + `svelte` (peer + dev) to the package; `build` runs `tsc` (headless) then `svelte-package` (`./ui`)
- [x] 1.2 `package.json`: `./ui` subpath export (`svelte` + `types` conditions), `files` includes the packaged ui output, `svelte` in `peerDependencies` (optional)
- [x] 1.3 Verify the headless subpaths still build and import without Svelte (`pnpm build:libs`, existing unit tests)

## 2. Move the chrome into the package

- [x] 2.1 `src/ui/ExcalidrawCanvas.svelte` — the canvas host (from `apps/web/src/lib/Canvas.svelte`), taking the store and optional overlay colours
- [x] 2.2 `src/ui/Excalidraw.svelte` — the full editor (from `apps/web/src/App.svelte`), markup and `data-testid`s preserved verbatim
- [x] 2.3 `src/ui/export-image.ts` moved from the app (offscreen rasterizer) and re-exported
- [x] 2.4 `src/ui/index.ts` exporting `Excalidraw`, `ExcalidrawCanvas`, `type UIOptions`, `defaultUIOptions`, `type OverlayColors`

## 3. Public API

- [x] 3.1 Props: `initialData`, `theme`, `viewMode`, `gridMode`, `zenMode`, `uiOptions`, `onReady(store)`, `onChange(scene)`; host-prop → store sync
- [x] 3.2 `uiOptions` deep-merge with `defaultUIOptions`; gate every piece of chrome (toolbar + tool list, panel, menu + entries, context menu + commands, palette, welcome, zoom/undo islands, quick arrows, generators)
- [x] 3.3 `viewMode`: force selection tool, hide creation chrome, swallow canvas pointer edits (pan/zoom still work); store remains fully capable
- [x] 3.4 Slots: `toolbarExtra`, `topRight`, `footer`
- [x] 3.5 Overlay colours: `OverlayOptions` fields + store `overlayColors`, defaults unchanged
- [x] 3.6 Theming: rename tokens to the documented `--excal-*` set on the component root (light + dark)

## 4. Demo app becomes a consumer

- [x] 4.1 `apps/web/src/App.svelte` reduced to `<Excalidraw>` + collab URL params + test hooks via `onReady`
- [x] 4.2 Delete the app's moved files; app depends on the package's `./ui`

## 5. Verification

- [x] 5.1 All existing unit + e2e suites pass unchanged (the regression net for the move)
- [x] 5.2 New e2e: `uiOptions` hides chrome (panel/menu hidden, toolbar limited to 3 tools) while drawing still works
- [x] 5.3 New e2e: `viewMode` blocks edits but allows pan/zoom; `onReady`/`onChange` fire
- [x] 5.4 New e2e: overridden CSS tokens + overlay colours render in the client's colours
- [x] 5.5 Unit: `uiOptions` deep-merge defaults; overlay colour defaults unchanged

## 6. Docs & spec sync

- [x] 6.1 README: embedding guide (install, `<Excalidraw>`, `uiOptions` table, theming variables, slots, view mode, migration note for the peer dep)
- [x] 6.2 `openspec validate` clean; archive after merge
