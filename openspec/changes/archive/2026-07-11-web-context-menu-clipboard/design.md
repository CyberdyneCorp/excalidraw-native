# Design — Web Context Menu & Clipboard

## Context

The core already implements the *operations*: `copyData()` serializes the
selection to an `.excalidraw` payload (with its files), `paste(json, offset)`
decodes, re-ids, offsets, and selects, `reorder` covers all four z-order
steps, and `setLink`/`setLocked`/`flip`/`group` exist. `insertImage` and
`createText` cover external paste targets, and Phase 3's
`lib/export-image.ts` already rasterizes to PNG bytes. What is missing: the
OS-clipboard bridge, style capture/apply, wrap-in-frame, and the menu.

## Goals / Non-Goals

**Goals:** system-clipboard cut/copy/paste (including external images and
text, pasted at the cursor); copy-as-PNG/SVG; copy/paste styles;
wrap-in-frame; full element context menu + a distinct empty-canvas menu.

**Non-Goals:** cross-tab element dragging; clipboard history; rich-text
paste (plain text only); pasting excalidraw.com *links*; the library panel
and share dialog (Phase 4).

## Decisions

**D1 — Clipboard via `paste`/`copy`/`cut` DOM events, not polling.** The app
listens on `window`; the handlers read/write `event.clipboardData` when
available (synchronous, no permission prompt) and fall back to
`navigator.clipboard.readText()`/`writeText()` for the menu items, where
there is no event. Menu "Copy to clipboard as PNG" uses
`navigator.clipboard.write([new ClipboardItem({"image/png": blob})])`, which
requires a user gesture — the menu click is one.
*Alternative:* clipboard-API-only — rejected: `readText()` prompts for
permission in some browsers, while the paste event carries the data for free.

**D2 — Paste target order.** A paste event is inspected in this order:
(1) `text/plain` that parses as an `.excalidraw` file → `controller.paste`;
(2) an image file in `clipboardData.files` → `insertImage` at the cursor;
(3) any other non-empty `text/plain` → a text element at the cursor. This
mirrors excalidraw and keeps our own payload authoritative.

**D3 — Paste position.** The store tracks the last pointer scene position
(already needed for `trackPointer`); paste offsets the incoming elements so
their bounding box centre lands there. With no pointer yet (fresh tab), it
falls back to the viewport centre.

**D4 — Style capture is a plain value object, not a scene mutation.**
`EditorController.styleOf(id): ElementStyle` returns a snapshot;
`applyStyle(style)` writes it to every selected element inside one
transaction, skipping properties that don't apply to a type (font on a
rectangle, arrowheads on an ellipse). The clipboard is *not* involved —
styles live in app state, like excalidraw (they survive selection changes
but not a reload).

**D5 — Wrap-in-frame reuses frame membership.** Create a frame element from
`selectionBounds` + margin, insert it *below* the selection in z-order, then
run the existing `reassignFrameMembership` so children adopt normally — one
transaction, one undo step.

## Risks / Trade-offs

- [Clipboard permissions differ across browsers/headless] → the e2e grants
  `clipboard-read`/`clipboard-write` in the Chromium context; the paste-event
  path (no permission needed) is what real users hit most.
- [`ClipboardItem` PNG write is unsupported in some browsers] → guarded with
  a capability check; the menu item hides where unsupported.
- [Pasted text could be huge] → the text element is created with the pasted
  string as-is; wrapping/measurement already handles multi-line text.

## Migration Plan

No data or protocol changes; the clipboard payload is the existing
`.excalidraw` format, so copy/paste interoperates with excalidraw.com in
both directions. One PR.

## Open Questions

- Whether Paste styles should also copy `strokeColor` onto text elements
  (excalidraw does — text colour is `strokeColor`). Assumed yes.
