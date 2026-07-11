# Embeddable, Customizable Web Editor

## Why

`@cyberdynecorp/excalidraw-svelte` publishes only headless logic — the store,
renderer, model, geometry, editor, and collab protocol. It contains **zero UI
components**: every piece of chrome we have (toolbar, style panel, context
menus, export dialog, command palette, welcome, help — ~2,000 lines) lives in
`apps/web`, which is explicitly *not published*. So a client integrating the
library either rebuilds the entire editor UI from scratch, or forks the demo
app and loses the upgrade path. Neither is acceptable for embedding.

There is also no way to customize what we *do* draw: the selection accent,
binding highlight, snap guides, and handle colours are `const`s inside
`overlay.ts`, and the app's design tokens are private CSS in an unpublished
app.

Excalidraw's own React package solves this with a configurable `<Excalidraw />`
component (`UIOptions`, `viewModeEnabled`, `theme`, `initialData`, render
slots). We should offer the equivalent.

## What Changes

- **Publish the editor as a component.** Move the app's UI into the package as
  `<Excalidraw />` (full editor) and `<ExcalidrawCanvas />` (bare canvas +
  overlay, no chrome), exported from a new `./ui` subpath. The package builds
  Svelte components with `@sveltejs/package`; `svelte` moves to a peer
  dependency.
- **Props API** — `initialData` (scene/document), `theme`, `viewMode`
  (read-only: no tools, no editing), `zenMode`, `gridMode`, `langCode`-free
  labels via `uiOptions`, and callbacks `onReady(store)` / `onChange(scene)`.
- **`uiOptions`** — hide or show any piece of chrome: the toolbar (and which
  tools appear in it), style panel, app menu (and individual entries: open,
  save, export, reset, theme, help), context menu (and individual commands),
  command palette, welcome screen, zoom/undo islands, quick-arrow buttons,
  and the generators.
- **Slots** for host-supplied chrome (`toolbarExtra`, `topRight`, `footer`) so
  a client can add their own buttons without forking.
- **Themeable overlay** — the interaction colours (selection accent, binding
  highlight, snap guides, handle fill) become `OverlayOptions`/store-level
  configuration instead of module constants.
- **Documented theming contract** — the component's CSS custom properties
  (`--excal-island`, `--excal-accent`, `--excal-ink`, …) become a public,
  documented API a client can override in their own stylesheet.
- `apps/web` becomes a thin consumer of the published component (proving the
  API), keeping every existing e2e test green.

## Capabilities

### New Capabilities

- `web-embedding`: the public component API — props, `uiOptions`, slots,
  theming contract, and view mode — that third-party clients integrate
  against.

### Modified Capabilities

- `web-client`: the chrome requirements now describe the *component's*
  behaviour (the demo app consumes it); the existing behaviour is unchanged
  from the user's point of view.
- `scene-rendering`: ADDED requirement — overlay interaction colours are
  configurable rather than fixed.

## Impact

- **BREAKING (package layout)**: `svelte` becomes a peer dependency, the
  package gains a `./ui` subpath, and the build switches to
  `@sveltejs/package` for the component entry (the headless subpaths keep
  their current `tsc` output and stay usable without Svelte).
- `web/packages/excalidraw-svelte`: new `src/ui/**` (Excalidraw.svelte,
  ExcalidrawCanvas.svelte, and the pieces of chrome as internal components),
  overlay colour options, packaging config.
- `web/apps/web`: reduced to a thin wrapper (collab URL params + test hooks).
- E2E: unchanged suites must keep passing against the component-driven app;
  new specs for `uiOptions` gating, view mode, and theme overrides.
- No schema, file-format, or protocol changes; iOS/Android untouched.
- Version: a **minor-with-breaking-packaging** bump (0.10.0) with migration
  notes in the README.
