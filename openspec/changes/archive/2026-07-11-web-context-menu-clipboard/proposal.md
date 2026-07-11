# Web Context Menu & Clipboard

## Why

The last open item of Phase 2 in the parity roadmap. The web context menu
offers 7 entries against excalidraw.com's ~18, and the app has no clipboard
integration at all: you cannot cut/copy/paste elements, paste an image or
text from outside the app, copy the drawing as an image to paste into
another tool, or reuse a shape's style. The editor core already implements
most of the *operations* (`copyData()` serializes the selection to an
`.excalidraw` payload, `paste(json)` re-ids and offsets it, all four z-order
steps, `setLink`, `setLocked`, `flip`) — what is missing is the OS-clipboard
bridge, style copy/paste, wrap-in-frame, and the menu itself.

## What Changes

- **Clipboard bridge** — Cut / Copy / Paste over the async Clipboard API with
  keyboard shortcuts (⌘X/⌘C/⌘V) and menu entries. Copy writes the
  `.excalidraw` payload as text; paste accepts: our payload (elements,
  re-id'd and offset), **image files** (inserted as image elements), and
  **plain text** (inserted as a text element). Pasting at the cursor
  position, like excalidraw.
- **Copy as image** — "Copy to clipboard as PNG" (via the Phase 3 export
  pipeline) and "Copy as SVG" (SVG string as text).
- **Copy / paste styles** — copy the selection's style properties and apply
  them to another selection (stroke, background, fill, widths, style,
  roughness, roundness, opacity, font, arrowheads).
- **Wrap selection in frame** — create a frame around the selection and adopt
  it (uses the existing frame membership logic).
- **Context-menu parity** — element menu: cut/copy/paste, copy as PNG/SVG,
  copy/paste styles, wrap in frame, 4-step z-order (send backward / bring
  forward / send to back / bring to front), flip H/V, add link, lock,
  duplicate, delete. Empty-canvas menu: paste, select all, zoom to fit.
- Small core additions: `styleOf(id)` / `applyStyle(style)` and
  `wrapSelectionInFrame()`; store passthroughs for cut/copy/paste that keep
  history semantics.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `web-client`: the context-menu requirement grows to the full command set
  plus an empty-canvas menu; new requirements for the clipboard bridge
  (cut/copy/paste incl. external images and text, copy-as-image) and style
  copy/paste.
- `selection-and-transform`: ADDED requirement — style copy/paste across a
  selection, and wrap-selection-in-frame.

## Impact

- `web/packages/excalidraw-svelte`: `EditorController.styleOf/applyStyle`,
  `wrapSelectionInFrame`; `EditorStore` cut/copy/paste passthroughs and
  `pasteImage`/`pasteText` helpers; unit tests.
- `web/apps/web`: `App.svelte` context menus (element + empty canvas),
  clipboard event wiring (`copy`/`cut`/`paste` listeners + shortcuts),
  reusing `lib/export-image.ts` for copy-as-PNG.
- E2E: clipboard round-trips (via the Clipboard API with granted
  permissions), style copy/paste, wrap in frame, z-order steps, empty-canvas
  menu.
- No schema, file-format, or protocol changes — the clipboard payload is the
  existing `.excalidraw` format, so copy/paste interoperates with
  excalidraw.com; iOS/Android untouched.
