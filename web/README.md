# excalidraw-web — TypeScript + Svelte 5 twin

The web implementation of the Excalidraw library, a twin of the Swift app under
`../Sources`. Both are built against the language-neutral [OpenSpec
specs](../openspec/specs/) and share golden fixtures so they can't drift. See
[docs/TYPESCRIPT_SVELTE_PORT.md](../docs/TYPESCRIPT_SVELTE_PORT.md) for the full
roadmap.

## Layout

```
web/
├── packages/
│   ├── math/      @xs/math — points, vectors, angles, curves, geometry  ✅ T0
│   ├── model/     @xs/model — element schema, scene, .excalidraw codecs ✅ T1
│   ├── geometry/  @xs/geometry — bounds, hit-test, snapping, elbow        (T2)
│   ├── render/    @xs/render — Canvas2D renderer, export                  (T3)
│   ├── editor/    @xs/editor — tools, selection, generators, smart        (T4)
│   ├── svelte/    @xs/svelte — Svelte 5 runes store + components          (T5)
│   └── protocol/  @xs/protocol — collaboration wire schema               (T7)
├── apps/web/      browser app                                             (T5)
└── server/        WebSocket relay                                         (T7)
```

## Develop

Requires Node ≥ 20.19 and pnpm 10.

```sh
pnpm install
pnpm test          # vitest across all packages
pnpm typecheck     # tsc --noEmit per package
pnpm lint          # biome
```

## Status

- **T0 — Foundations:** `@xs/math` ported from `ExcalidrawMath` with the Swift
  unit tests ported to Vitest (67 tests). Strict TS (`noUncheckedIndexedAccess`).
- **T1 — Model & file format:** `@xs/model` ported from `ExcalidrawModel` — the
  flat element schema (13 types), `Scene` with versioned `mutate`, diff-based
  `History`/`Store` undo-redo, `restore` + fractional indexing, and the
  `.excalidraw` / `.excalidrawlib` codecs with canonical (sorted-key) JSON.
  39 tests, including a **cross-language round-trip** that reads the shared
  `../Fixtures/*.excalidraw` and asserts the re-encode is semantically
  diff-clean against the Swift-authored source.
