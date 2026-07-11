# Design — Web App Chrome & Flows

## Context

The editor core already provides every mechanism these flows need:
`toolLocked` is honoured by both `finishCreating` and `finishPendingLinear`
(just unreachable from the UI), the PNG scene-embed codec
(`embedScene`/`extractScene`/`containsScene`, CRC-32 `tEXt` chunks,
excalidraw-compatible) is implemented and unit-tested, `loadDocument`
round-trips `.excalidraw` JSON, `exportSvg` renders a scene, and
`selectionOrContentBounds` gives export bounds. Phase 3 is host wiring:
menu, dialogs, overlays, and an offscreen-canvas rasterizer.

## Goals / Non-Goals

**Goals:** tool lock UI; app menu (open/save/export/reset/theme/help);
export dialog (PNG/SVG, scale, background, selection-only, embed);
PNG-embed round-trip via Open; welcome + help overlays; renderer background
override for exports.

**Non-Goals:** context-menu/clipboard parity (Phase 2 leftover, separate
change); library panel, zen mode, command palette, zoom-to-fit (Phase 4);
autosave/recents; PDF or clipboard image export.

## Decisions

**D1 — PNG rasterization lives in the app, not the package.** A small
`lib/export-image.ts` creates an offscreen `<canvas>` sized to the content
bounds (+16px margin) × scale, builds a `Viewport` that fits those bounds,
calls the package's `renderScene` (light theme, background override), and
encodes via `canvas.toBlob("image/png")` → `Uint8Array` → `embedScene`.
The package stays DOM-free (its renderer keeps taking a context, not a
canvas). Selection-only exports render a temporary `Scene` of the selected
elements (plus their bound labels).

**D2 — Renderer background override, not post-processing.**
`RenderOptions.background?: string | "transparent"` short-circuits the
background fill for that pass. Transparent PNGs need the fill skipped —
erasing afterwards would also erase element pixels.

**D3 — Open accepts both formats through one input.** The file input takes
`.excalidraw,.png`; PNG bytes go through `containsScene`/`extractScene`
(rejecting PNGs without a scene, with a visible message), JSON goes through
`loadDocument`. A store `openDocument(scene)`/existing `loadDocument` keeps
history semantics (load = fresh baseline, like today).

**D4 — Reset canvas is a plain undoable transaction** (`replaceAll([])` +
commit) — cheaper than a confirm dialog and safer than a destructive clear.

**D5 — Welcome/help are pointer-transparent overlays** (`pointer-events:
none` for welcome; help is a modal island with a backdrop like the existing
menus). Welcome visibility: scene empty AND selection tool active AND not
editing — no stored "seen" flag, matching excalidraw's behaviour of showing
it on any empty canvas.

## Risks / Trade-offs

- [`canvas.toBlob` is async and e2e downloads are awkward] → the export
  helper returns bytes; the UI wraps them in a download. E2E asserts via
  Playwright `download` events plus a byte-level round-trip test done in
  `page.evaluate` (export bytes → extractScene → element count).
- [Selection-only must include bound labels] → the temporary scene copies
  `boundElements` targets of selected containers explicitly.
- [Fonts in PNG exports depend on document fonts] → same face the canvas
  uses; bundled-font work stays a known gap (roadmap).

## Migration Plan

No data or protocol changes; one PR. The PNG embed uses the existing
excalidraw-compatible codec, so exported PNGs also open on excalidraw.com.

## Open Questions

- None blocking; a future `persistence`-style web capability spec could
  absorb autosave/recents when Phase 4 lands.
