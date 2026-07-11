# Design — Embeddable, Customizable Web Editor

## Context

The package is headless by construction: `tsc`-built TS with no `.svelte`
files, and `apps/web` holds all ~2,000 lines of chrome but is unpublished.
Clients therefore cannot embed our editor — only rebuild it. Excalidraw's
React package solves this with a configurable component; we need the Svelte
equivalent without giving up the headless entry points (the Yjs adapter, the
relay, and non-Svelte consumers depend on them).

## Goals / Non-Goals

**Goals:** publish `<Excalidraw>` and `<ExcalidrawCanvas>`; props for
`initialData` / `theme` / `viewMode` / `gridMode` / `zenMode` / `uiOptions` /
`onReady` / `onChange`; per-piece chrome gating; overlay colour options; a
documented CSS-variable theming contract; slots for host chrome; `apps/web`
reduced to a thin consumer so the API is dogfooded and every e2e still passes.

**Non-Goals:** i18n/localization (labels stay English; a `labels` prop is a
follow-up); React/Vue wrappers; plugin system; per-element permission model;
changing any editor behaviour.

## Decisions

**D1 — `@sveltejs/package` for a `./ui` subpath only.** The headless subpaths
keep their `tsc -p tsconfig.build.json` output (unchanged consumers, no Svelte
needed). A second build step (`svelte-package`) emits `dist/ui/**` with
compiled-on-consume `.svelte` sources plus generated `.d.ts`, and
`package.json` gains `"./ui": { "svelte": …, "types": … }`. `svelte` moves to
`peerDependencies` — it is only required by the `./ui` path.
*Alternative:* ship prebuilt JS from `svelte-compile` — rejected: it pins the
consumer to our Svelte version; shipping sources is the ecosystem norm.

**D2 — `uiOptions` is a deep-partial config object, not a slot soup.**
Shape: `{ toolbar: false | { tools?: Tool[], lock?: boolean, more?: boolean },
panel: boolean, menu: false | { open?, save?, export?, reset?, theme?, help? },
contextMenu: false | { …commands }, palette: boolean, welcome: boolean,
zoomIsland: boolean, undoIsland: boolean, quickArrows: boolean,
generators: false | { note?, table?, chart?, mermaid? } }`. Every field
defaults to *enabled*, so `<Excalidraw />` with no props is today's app.
Merged with `defaultUIOptions` via a small deep-merge helper (typed, no
dependency).

**D3 — `viewMode` is enforced in the component, not the core.** It forces the
selection tool, hides creation chrome, and swallows pointer *down/move/up* on
the canvas except pan/zoom. The store stays fully capable (a host embedding a
read-only view can still programmatically edit) — this matches the spec's
"hiding chrome does not remove capability" rule and keeps the core free of a
permission concept.

**D4 — Overlay colours become `OverlayOptions` fields with the current
constants as defaults.** The store gains an `overlayColors` field the
component sets from its prop, and passes into `renderOverlay`. No model or
protocol impact — the overlay is ephemeral chrome.

**D5 — Theming via prefixed CSS custom properties.** The app's private tokens
are renamed to a public, documented set (`--excal-island`, `--excal-ink`,
`--excal-muted`, `--excal-border`, `--excal-hover`, `--excal-accent`,
`--excal-accent-ink`, `--excal-shadow`) defined on the component root for both
themes; clients override them in their own stylesheet. Prefixing avoids
collisions with the host app's variables.

**D6 — The demo app keeps its testids.** The chrome moves wholesale into the
component with its `data-testid`s intact, so all 60 existing e2e tests keep
passing and act as the regression net for the refactor. `apps/web` retains
only: collab URL-param wiring, the `window.__store` / `__exportPng` test
hooks (via `onReady`), and mounting `<Excalidraw>`.

## Risks / Trade-offs

- [Large mechanical move could regress behaviour] → the existing e2e suite is
  the safety net; the move preserves markup and testids verbatim, and the
  suite must stay green at every step.
- [Peer-dep change is breaking for consumers] → documented in the README with
  a migration note; headless users are unaffected in practice (they already
  have Svelte or don't use `./ui`).
- [`svelte-package` adds build surface] → confined to one extra script and the
  `./ui` export; CI already builds and tests the workspace.

## Migration Plan

Ship as one PR. Consumers of the headless subpaths need no change. Consumers
who want the UI add `svelte` (peer) and import from `.../ui`. Release as
0.10.0 with README migration notes.

## Open Questions

- A `labels` prop for i18n: deferred to a follow-up (`web-i18n`), since it
  touches every component and deserves its own spec.
