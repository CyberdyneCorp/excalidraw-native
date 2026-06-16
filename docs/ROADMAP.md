# Excalidraw-Swift — Roadmap

Vertical-slice-first delivery: get a thin end-to-end path working early (draw → rough render → select/move → save/load → export), then widen feature by feature. Each phase ends with a working, tested build. Coverage gate (≥90%) and CI green are exit criteria for every phase.

Legend: 🎯 milestone deliverable · 🧪 test focus · ⚠️ risk/hard part.

---

## Phase 0 — Foundations & CI
**Goal:** buildable workspace, test harness, coverage gating.
- SwiftPM workspace with the package split from [PLAN.md §2](./PLAN.md): `ExcalidrawMath`, `ExcalidrawModel`, `ExcalidrawGeometry`, `RoughKit`, `FreehandKit`, `ExcalidrawRender`, `ExcalidrawUI`, `ExcalidrawApp`.
- Xcode app target (iOS 17+), iPhone + iPad. SwiftLint + formatting.
- GitHub Actions: build + `swift test` + `xcodebuild test`, coverage report, 90% gate, golden-image diff artifacts.
- Import upstream test fixtures and a corpus of `.excalidraw` sample files.
- 🎯 CI green on an empty but wired project; one trivial test per package.

## Phase 1 — Domain core: model + geometry + file format ✅
**Goal:** the engine, fully testable, no UI.

> **Status: complete.** Delivered: `ExcalidrawModel` (element model, file format, Scene, Store/Delta/History, Restore), `ExcalidrawMath` (point/vector/angle/range/line/segment/triangle/rectangle/polygon/ellipse/curve), `ExcalidrawGeometry` (bounds + hit-testing). `.excalidraw` round-trips diff-clean against the fixture corpus. **Deferred to later increments/phases:** full rocicorp fractional-indexing + legacy binding-v1 migration (incremental), property-level partial deltas & AppState history (collab-oriented), exact cubic-Bézier bounds and rounded-corner hit-testing, and the heavy curve algorithms — Newton curve↔line intersection, Legendre–Gauss arc length, elbow A* (Phase 7).
- `ExcalidrawMath`: port `packages/math` (point, vector, line, segment, curve, ellipse, polygon, angle, range) 1:1. 🧪 property/fixture tests.
- `ExcalidrawModel`: `ExcalidrawElement` enum + base props, AppState, Scene store with indices, fractional index, Store/Delta/History. Custom `Codable`.
- Persistence: port `restore.ts` as the single load path (index gen, ref repair, binding migration, normalization, clamping). PNG-scene embed deferred.
- `ExcalidrawGeometry`: bounds (incl. rotated + Bézier bbox), hit-testing (ray cast + distance), basic curve sampling. *(Newton intersect, elbow A*, Legendre-Gauss deferred to Phase 7.)*
- 🧪 Codable round-trip on the sample corpus (incl. older schema versions); structural equality after restore→encode; hit-test fixtures.
- ⚠️ Round-trip fidelity vs excalidraw.com — build the interop corpus now.
- 🎯 Load any real `.excalidraw`, mutate via API, save it back, diff-clean.

## Phase 2 — RoughKit + first pixels ✅
**Goal:** the hand-drawn look, one shape on screen.

> **Status: complete.** `RoughKit` ports rough.js — RNG matched to `Math.imul(48271, seed)`, the double-stroke `_line`/`_doubleLine`/`linearPath`, `polygon`/`rectangle`, `curve`/`_computeEllipsePoints` ellipses, and fills (solid/hachure/cross-hatch/zigzag). `ExcalidrawRender` adds `RoughOptionsBuilder` (`generateRoughOptions`), `ElementDrawable`, `ShapeCache`, and a `SceneRenderer` (viewport transform, grid, per-element transform/opacity, stroke/fill, Core Text, images, freedraw). `SceneCanvasView` renders a real scene via SwiftUI `Canvas` + `withCGContext`; the app loads and draws a bundled `.excalidraw` (verified on the iOS 17 simulator). **rough.js parity validated:** RoughKit's RNG, line, rectangle, ellipse, and outline-with-fill match rough.js 4.6.6 exactly to 1e-4 (reference captured via `scripts/rough_ref.cjs`, asserted in `RoughJSParityTests`). **Deferred:** hachure fill is visually faithful but not line-identical (scan-line edge handling differs); perfect-freehand pressure outlines and bundled Excalidraw fonts + exact text metrics (Phase 4); committed golden-image references; Metal fast-path if profiling needs it.
- `RoughKit`: seeded RNG, polyline perturbation, `Drawable` generation for rectangle/ellipse/polygon/linearPath/curve; fill styles (hachure, cross-hatch, solid, zigzag); dash/dotted; roughness scaling; `preserveVertices`. Renders into `GraphicsContext`/`CGContext`.
- `ExcalidrawRender`: SceneRenderer (static), ShapeCache, `Viewport` transforms, grid.
- Minimal `CanvasView` rendering a loaded scene (read-only) with pan/zoom.
- 🧪 RoughKit determinism (seed → identical paths); golden-image tests vs JS-rendered references for rect/ellipse/diamond/line across fill+stroke styles.
- ⚠️ rough.js visual fidelity — this phase de-risks the whole project.
- 🎯 Open a real `.excalidraw` and see it rendered with the correct hand-drawn look.

## Phase 3 — Interaction loop & first tools (the vertical slice closes) ✅
**Goal:** draw, select, move, resize, rotate, undo, export — end to end.

> **Status: complete.** New pure `ExcalidrawEditor` module: `PointerEvent`, `Tool`, `CurrentItemProperties`, `Transform` (resize/scale/translate/rotate math + handle layout), and the `EditorController` state machine (create-by-drag, select, multi-select box, move, resize via 8 handles, rotation, undo/redo, delete). `ExcalidrawRender` adds `InteractiveRenderer` (selection box + handles + marquee) and `Exporter` (PNG fit-to-content). `ExcalidrawUI` adds `EditorModel` (SwiftUI bridge), `EditorView` (toolbar + canvas + properties bar), and `PointerInputView` (raw `UITouch`: pressure, pencil-vs-finger, palm rejection, two-finger pan/zoom). The app is the editor; the XCUITest draws → exports → undoes on the iOS 17 simulator. **Deferred:** arrow/freedraw/text/image tools and rich properties (Phase 4); rotated-element resize is AABB-approximate; Apple Pencil hover and coalesced-touch freehand (Phase 4/5).
- Custom `UIViewRepresentable` exposing raw `UITouch` (force, type, coalesced, hover). `PointerController` state machine + `GestureCoordinator` (1-finger action, 2-finger pinch-zoom/pan).
- Tools: selection, rectangle, diamond, ellipse, line. Drag-to-create; multi-select; transform handles (pointer-type-aware sizes); rotation; move.
- Interactive overlay Canvas (selection box, handles, snap-to-grid).
- Undo/redo wired to Store/History.
- Exporter: PNG via `UIGraphicsImageRenderer`.
- Minimal toolbar + a few properties (stroke color, width).
- 🧪 Transform math tests; XCUITest: draw rect → move → resize → undo → export, on iPhone + iPad.
- 🎯 **Vertical slice complete**: create/edit a drawing from scratch and export it.

## Phase 4 — Full tool set & properties ✅

> **Status: complete.** Tools added: arrow (with arrowheads), freedraw (FreehandKit pressure outlines), text (on-canvas editing), image insert (PhotosPicker), eraser, hand. Properties: stroke/background colour, fill style, stroke style, stroke width, opacity — applied to current-item defaults and the selection. Actions: group/ungroup, duplicate, lock, z-order (front/back/forward/backward), align, flip — all undoable. Copy/paste via the `.excalidraw` payload (carries image files). SVG export (`SVGExporter`). New `FreehandKit` (perfect-freehand port). Full toolbar + properties bar in `EditorView`; XCUITest draws a shape, freedraws, places text, and exports on the iOS 17 simulator. **Deferred:** font family/size & arrowhead-type pickers, exact perfect-freehand parity (no local reference), bundled fonts + exact text metrics, laser pointer, eraser/laser animated trails (Phase 5+).

## Phase 4 — Full tool set & properties (original plan)
**Goal:** all core element types and styling.
- Tools: arrow (straight/curved), freedraw (`FreehandKit` port, pressure via `UITouch.force` + coalesced touches), text (Core Text `TextLayout`, on-canvas editing), image (insert from Photos/Files, files store), eraser (AnimatedTrail + intersection), hand/pan, laser.
- Properties panel: background color, fill style, stroke style, roundness, opacity, font family/size/text align, arrowheads, arrow type. Color picker + eyedropper.
- Actions: group/ungroup, duplicate, delete, align/distribute/flip, z-order, lock.
- Copy/paste via `UIPasteboard` (native + Excalidraw formats).
- SVG export.
- 🧪 FreehandKit outline tests; TextLayout metrics vs JS fixtures; per-tool e2e steps.
- ⚠️ Core Text metric parity — validate early in this phase.
- 🎯 Feature-complete single-user editor for all core element types.

## Phase 5 — Adaptive UI for iPhone & iPad ✅
**Goal:** great UX on both form factors, Pencil-first.

> **Status: complete.** Testable cores: `DeviceClass`/`FormFactor` breakpoints, `Shortcuts` (key chords → commands), `CommandRegistry` (palette + fuzzy search), `Theme`/`ThemeFilter` (dark mode via invert + 180° hue-rotate), `SceneDocument` (encode/decode through restore). `EditorModel` adds zoom (in/out/reset/fit), command dispatch, clipboard (`Pasteboard`), theme/zen toggles, and document save/load. `EditorView` is size-class adaptive (toolbar top on iPad / bottom on iPhone), with a zoom/theme/zen/palette footer, on-canvas context menu, hardware-keyboard shortcuts, and a searchable command palette. The XCUITest passes on both iPhone (compact) and iPad (regular) simulators. **Deferred:** Files-app `DocumentGroup` browser + autosave wiring (persistence core is done and tested), Apple Pencil hover (17.5+) and Pencil Pro, full font/arrowhead pickers.
- Size-class-adaptive layout: iPhone bottom toolbar + bottom-sheet properties, fullscreen dialogs; iPad side panels, floating/docked, hover affordances.
- Apple Pencil: hover preview (17.5+), palm rejection, pen-mode toggle; (Pencil Pro squeeze/roll behind availability checks).
- Context menu (long-press / right-click), command palette, keyboard shortcuts (iPad hardware keyboard), zoom controls, dark mode, zen/view modes.
- Document browser integration (Files app), autosave, recent docs.
- 🧪 Snapshot tests across size classes/orientations; XCUITest on iPhone + iPad; Pencil/pressure paths via injectable input.
- 🎯 Ships as a usable iPhone + iPad app.

## Phase 6 — Library, persistence polish, snapping & binding
**Goal:** the "important" tier from the investigation.
- Library (`.excalidrawlib`): save/browse/search/drag-to-canvas; local persistence.
- Object snapping (point + gap snaps) and snap-line rendering; midpoint snapping.
- Arrow↔shape binding (suggested binding, focus point, fixed-point modes); linear element midpoint editing.
- Image crop editor. PNG scene-embed round-trip. Stats panel. Element linking. Frames (containers, clipping, names).
- 🧪 Binding + snapping fixtures; library round-trip; frame clipping golden images.
- 🎯 Parity with everyday excalidraw.com usage.

## Phase 7 — Advanced geometry & remaining parity
**Goal:** the hard algorithms and long-tail features.
- Elbow arrows: port `heading.ts` + `elbowArrow.ts` (A* grid routing, fixed segments). Newton curve↔line intersection; Legendre-Gauss arc length. (Enables precise binding/curve interactions.)
- Embeddables/iframes (where iOS allows), flowchart helpers.
- Localization infra + initial locales (RTL support).
- Performance pass: profiling, dirty-region overlay, optional Metal fast-path if needed.
- 🧪 Elbow-routing fixtures from upstream; perf benchmarks (large scenes).
- ⚠️ Elbow A* is the most complex single algorithm — schedule generous time.
- 🎯 Feature parity (single-user) with upstream.

## Phase 8 — Collaboration & cloud (optional / future)
**Goal:** multiplayer, if pursued.
- Reuse Delta/Store sync unit + fractional indexing already in place.
- WebSocket/Firebase transport, collaborator cursors/presence, conflict resolution, follow mode.
- Mermaid-to-diagram, spreadsheet charts, AI/magic features as separate opt-in modules.
- 🎯 Real-time collaboration parity.

---

## Sequencing rationale
- **Phases 0–3 close the vertical slice** and de-risk the two scariest unknowns early: rough.js fidelity (Phase 2) and the raw-touch interaction layer (Phase 3).
- **File-format fidelity is front-loaded** (Phase 1) so every later phase reads/writes real Excalidraw files.
- **Hard algorithms (elbow A*, Newton intersect) are deferred** (Phase 7) behind the features that don't need them, so they never block a shippable build.
- **Collaboration is last and optional** but the data model (deltas, fractional indices, version nonces) is built collaboration-ready from Phase 1.
