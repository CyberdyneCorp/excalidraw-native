# Excalidraw-Swift

A native iOS (iPhone + iPad) port of [Excalidraw](https://excalidraw.com) in Swift / SwiftUI, aiming for feature parity with the web app, first-class Apple Pencil support, and finger-friendly UX.

> Status: **planning**. No app code yet — this repo currently holds the investigation and plan derived from the upstream Excalidraw source.

## Design decisions
- **Rendering:** SwiftUI `Canvas` + Core Graphics (static scene + interactive overlay), with a Swift port of rough.js (`RoughKit`) for the hand-drawn look.
- **Minimum OS:** iOS 17+ (`@Observable`, mature Canvas, Apple Pencil hover on 17.5+).
- **Delivery:** vertical-slice-first — a thin end-to-end path early, then widen.
- **Quality:** >90% test coverage, golden-image render tests, XCUITest e2e on iPhone + iPad.
- **Compatibility:** `.excalidraw` / `.excalidrawlib` round-trip with excalidraw.com.

## Documents
- **[docs/INVESTIGATION.md](docs/INVESTIGATION.md)** — analysis of the upstream source: data model, file format, rendering pipeline, interaction model, geometry/math, and full feature inventory.
- **[docs/PLAN.md](docs/PLAN.md)** — architecture, Swift package structure, key design decisions, testing strategy, risks.
- **[docs/ROADMAP.md](docs/ROADMAP.md)** — phased delivery plan (Phase 0 foundations → Phase 8 collaboration).

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

`ExcalidrawMath` → `ExcalidrawModel` → `ExcalidrawGeometry` · `RoughKit` · `FreehandKit` → `ExcalidrawRender` → `ExcalidrawUI` → `ExcalidrawApp`

See [PLAN.md §2](docs/PLAN.md) for details.
