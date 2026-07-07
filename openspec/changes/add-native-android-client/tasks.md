> **Milestone 1 (delivered & verified on an API-34 emulator).** A compiling,
> unit-tested `:core-model` (`.excalidraw` lenient decode + tolerant bindings +
> lossless round-trip) and a `:app` Compose/Skia client that renders all element
> types and supports pan/zoom + drag-to-create shapes and freehand. Remaining
> tasks below (hand-drawn ports, selection/transform, history, full tool set,
> export, collaboration, per-module split, CI) are the follow-on milestones.
> The module graph currently contains `:core-model` and `:app`; the other
> modules are introduced as their milestones land.

## 1. Project skeleton & tooling

- [ ] 1.1 Add an `android/` Gradle project with the module graph: `core-math`, `core-model`, `core-geometry`, `rough-kotlin`, `freehand-kotlin`, `render-compose`, `editor`, `collab-yjs`, `app` (empty modules, wired dependencies mirroring the Swift core layering)
- [x] 1.2 Pin minimum Android API level, Kotlin/Compose versions, and stylus support matrix; document them in `android/README.md`
- [ ] 1.3 Add ktlint + detekt config and a `./gradlew check` that runs lint + unit tests
- [ ] 1.4 Add a shared golden test corpus location (reuse existing `.excalidraw` fixtures + reference renders from iOS/web)

## 2. Core model, math & geometry (parity: data-model, file-format, geometry-and-math)

- [ ] 2.1 Implement `core-math` (points, vectors, transforms) with unit tests
- [x] 2.2 Implement `core-model` element types + flat-JSON `.excalidraw` coding
- [x] 2.3 Implement lenient decode: missing keys default rather than fail (incl. tolerant arrow/`FixedPointBinding` decode)
- [x] 2.4 Implement lossless passthrough of unmodelled data (`customData`, unknown app-state keys)
- [ ] 2.5 Implement `core-geometry` (hit-testing, bounds, curves) with unit tests
- [x] 2.6 Golden round-trip test: load iOS/web-authored corpus, assert modelled equivalence + unmodelled-field preservation (satisfies `.excalidraw` round-trip conformance)

## 3. Hand-drawn rendering (parity: hand-drawn-rendering)

- [ ] 3.1 Port rough.js to `rough-kotlin`: hachure + solid fills, sloppiness/roughness, seeded RNG
- [ ] 3.2 Test seeded-roughness stability (same seed → identical geometry across renders)
- [ ] 3.3 Port perfect-freehand to `freehand-kotlin`: pressure-based stroke outlines
- [ ] 3.4 Golden-image tolerance tests for rough + freehand output vs iOS/web references

## 4. Scene rendering (parity: scene-rendering)

- [x] 4.1 Implement `render-compose` scene renderer on Compose Canvas (Skia) with layered caching
- [x] 4.2 Keep text on a Compose text layer (never rasterized into the vector cache); verify crispness at high zoom
- [ ] 4.3 Golden-image tests: Android render matches iOS/web golden within tolerance

## 5. Editor state machine (parity: drawing-tools, selection-and-transform, editing-history)

- [ ] 5.1 Implement `editor` as a Compose-free state machine (no UI-framework coupling); assert via unit tests
- [ ] 5.2 Implement all drawing tools to match `drawing-tools`
- [ ] 5.3 Implement selection + transform to match `selection-and-transform`
- [ ] 5.4 Implement undo/redo history to match `editing-history`
- [ ] 5.5 Unit tests: create → select → transform → undo/redo produce the shared-spec element models

## 6. Compose app host & input

- [x] 6.1 Build the Jetpack Compose UI shell (canvas host, tool palette, navigation, pan/zoom)
- [ ] 6.2 Route touch and stylus input (incl. pressure) to the active tool
- [ ] 6.3 Instrumented/UI parity tests for the core editing flows

## 7. Collaboration (parity: collaboration, collaboration-yjs)

- [ ] 7.1 Select the Yjs implementation (y-crdt JNI binding vs pure-Kotlin port) by running both through the cross-peer convergence suite
- [ ] 7.2 Implement `collab-yjs` adapter: id-keyed per-element map, soft-delete tombstones, fractional-index z-order — isolated from the editor core
- [ ] 7.3 Wire join/leave, presence, and live sync into the app host
- [ ] 7.4 Cross-peer interop test: mixed Android + iOS/web room converges on concurrent add/move/delete/reorder
- [ ] 7.5 Late-joiner test: Android joins an existing iOS/web room and receives full state

## 8. Export

- [ ] 8.1 Implement PNG export of the rendered scene
- [ ] 8.2 Implement `.excalidraw` export preserving unmodelled data
- [ ] 8.3 Test exported files open on iOS/web with modelled + unmodelled data intact

## 9. CI & baseline docs

- [ ] 9.1 Add an Android CI job: `assemble`, unit tests, instrumented/UI tests, ktlint/detekt
- [ ] 9.2 Add cross-client golden round-trip + live collaboration interop tests to CI
- [x] 9.3 Update `openspec/project.md` baseline: multi-platform (iOS/Swift, web/Svelte, Android/Kotlin) unified by `.excalidraw` format + Yjs wire protocol
- [ ] 9.4 Update repo README/docs to document the Android client and how to build/run it

## 10. Validation & archive

- [ ] 10.1 Run `openspec validate add-native-android-client --strict` and confirm all parity/interop tests are green
- [ ] 10.2 Archive the change (`/opsx:archive`) so `android-client` becomes a living baseline spec
