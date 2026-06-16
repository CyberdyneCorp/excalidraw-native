# Excalidraw-Swift

A native iOS (iPhone + iPad) port of [Excalidraw](https://excalidraw.com) in Swift / SwiftUI, aiming for feature parity with the web app, first-class Apple Pencil support, and finger-friendly UX.

> Status: **feature-complete for single-user editing** (roadmap Phases 0–7 done, plus tables & charts, plus Phase 7.5 rendering acceleration incl. a Metal GPU backend). Runs on the iPhone + iPad simulators and device. 534 tests passing, ~94% logic coverage, CI green. Remaining work is collaboration (Phase 8, optional) and a set of tracked gaps — see **[Known gaps](#known-gaps)** below and the consolidated list in [docs/ROADMAP.md](docs/ROADMAP.md#known-gaps--deferred-items).

## What works today
- **Drawing & tools:** rectangle, diamond, ellipse, line, arrow (incl. **elbow/orthogonal** arrows with draggable fixed segments), freedraw (pressure), text, image, eraser, hand, frames, **sticky notes**, **tables**, **charts** (bar/line).
- **Hand-drawn rendering:** `RoughKit` (rough.js port, numeric parity validated), all fill styles, **sloppiness** (architect/artist/cartoonist), sharp/round edges, splined multi-point lines, rounded rectangles.
- **Rendering backends:** Core Graphics (default) + an optional **Metal GPU renderer** (`ExcalidrawMetal`), runtime-switchable via a footer toggle with automatic CG fallback. Layered static/dynamic split + gesture snapshots keep the CPU path smooth; the GPU path tessellates shapes/freedraw/dashed strokes/images and (in the editor) presents direct-to-`CAMetalLayer` with a CG overlay for crisp text. An in-app benchmark screen compares CPU vs Metal vs Direct vs the editor hybrid across every component type. See [Phase 7.5](docs/ROADMAP.md#phase-75--rendering-acceleration--performance).
- **Editing:** select/multi-select, group-aware selection, move/resize/rotate, **font scales on resize**, undo/redo, copy/paste, z-order, align, flip, group/ungroup, lock, duplicate.
- **Smart features:** object + gap snapping, arrow↔shape binding, **freehand shape recognition** ("Snap to Shape": rectangle/ellipse/diamond/triangle/line/pentagon/hexagon/star/heart/cloud/speech-bubble, hold-to-snap), flowchart node spawning, interactive image crop, element hyperlinks.
- **Platform:** size-class-adaptive iPhone/iPad UI, dark mode, zen mode, command palette, hardware-keyboard shortcuts, two-finger pan/zoom, palm rejection, localization infra (en/es/ar incl. RTL).
- **Files:** `.excalidraw` / `.excalidrawlib` round-trip; PNG & SVG export; on-disk library.

<a name="known-gaps"></a>
## Known gaps (not yet implemented)
Tracked deferrals, in sync with the code. Full detail in [docs/ROADMAP.md](docs/ROADMAP.md#known-gaps--deferred-items).
- **Collaboration / cloud** (Phase 8) — multiplayer, presence, cursors (data model is collab-ready).
- **Mermaid → diagram** — the text→elements parser isn't built (tables/charts shipped).
- **Embeddables / iframes** — render as labelled placeholders; no live `WKWebView` embedding.
- **Rendering** — ✅ delivered as [Phase 7.5](docs/ROADMAP.md#phase-75--rendering-acceleration--performance): layered static/dynamic split, gesture snapshots, and a runtime-selectable **Metal GPU backend** (1.9–2.9× faster than CPU on device for all-component scenes). Remaining nuance: **text** stays on the Core Graphics overlay by design (a GPU glyph atlas would pixelate at zoom; SDF GPU text is a possible future option), and the GPU path doesn't use the incremental-redraw `clip` (it repaints the full viewport — idempotent, perf-only).
- **Fidelity** — bundled Excalidraw fonts + exact text metrics (uses system fallbacks); hachure fill and perfect-freehand outlines are visually faithful, not line-identical; no committed golden-image references.
- **UI polish** — custom/eyedropper color picker (only preset swatches), arrowhead-type picker, Files-app `DocumentGroup` browser + autosave, laser pointer & animated eraser trail.
- **Apple Pencil** — hover preview (17.5+) and Pencil Pro squeeze/roll.
- **Persistence** — PNG scene-embed round-trip (re-open a scene from an exported PNG).

## Design decisions
- **Rendering:** SwiftUI `Canvas` + Core Graphics (static scene + interactive overlay), with a Swift port of rough.js (`RoughKit`) for the hand-drawn look; an optional Metal GPU backend (`ExcalidrawMetal`) is swappable at runtime behind a `SceneRendering` protocol, with CG as the default and automatic fallback.
- **Minimum OS:** iOS 17+ (`@Observable`, mature Canvas, Apple Pencil hover on 17.5+).
- **Delivery:** vertical-slice-first — a thin end-to-end path early, then widen.
- **Quality:** >90% test coverage, golden-image render tests, XCUITest e2e on iPhone + iPad.
- **Compatibility:** `.excalidraw` / `.excalidrawlib` round-trip with excalidraw.com.

## Documents
- **[docs/INVESTIGATION.md](docs/INVESTIGATION.md)** — analysis of the upstream source: data model, file format, rendering pipeline, interaction model, geometry/math, and full feature inventory.
- **[docs/PLAN.md](docs/PLAN.md)** — architecture, Swift package structure, key design decisions, testing strategy, risks.
- **[docs/ROADMAP.md](docs/ROADMAP.md)** — phased delivery plan (Phase 0 foundations → Phase 8 collaboration), with per-phase status and a consolidated **[Known gaps & deferred items](docs/ROADMAP.md#known-gaps--deferred-items)** list.

## Building

Open **`ExcalidrawSwift.xcodeproj`** and run the `ExcalidrawApp` scheme. The
project is committed to the repo (it's generated from `project.yml` via
[XcodeGen](https://github.com/yonsm/XcodeGen) but kept in git so it's stable).
The libraries also build and test without Xcode via `swift build` / `swift test`.

Regenerate the project only after changing `Package.swift` (targets/products)
or `project.yml`, then commit the result:

```sh
brew install xcodegen        # once
./scripts/generate.sh        # regenerate + clear stale caches
```

If Xcode ever reports **"Missing package product"** or **"Couldn't load
project"**, it's stale package state: run `./scripts/generate.sh` (it clears
`.swiftpm` and this project's DerivedData), then **quit and reopen**
`ExcalidrawSwift.xcodeproj` — open the `.xcodeproj`, not the folder or
`Package.swift`.

## Architecture at a glance
Layered, framework-light core (pure Swift, simulator-independent) under a thin SwiftUI shell:

`ExcalidrawMath` → `ExcalidrawModel` → `ExcalidrawGeometry` · `RoughKit` · `FreehandKit` → `ExcalidrawRender` → `ExcalidrawMetal` · `ExcalidrawEditor` → `ExcalidrawUI` → `ExcalidrawApp`

(`ExcalidrawEditor` is the pure, UIKit-free editor state machine — tools, selection/transform, undo, and all the generators/algorithms — bridged to SwiftUI by `ExcalidrawUI`'s `EditorModel`. `ExcalidrawMetal` is the optional GPU renderer — scene→triangle tessellation, an image texture cache, and the `CAMetalLayer` present path — behind the same `SceneRendering` protocol as the Core Graphics `SceneRenderer`.)

See [PLAN.md §2](docs/PLAN.md) for details.
