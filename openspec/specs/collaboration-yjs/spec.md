# Collaboration (Yjs adapter)

## Purpose

An **optional, alternative** web collaboration backend that represents the scene
as a Yjs CRDT (`Y.Doc`) and two-way binds it to the editor, so adopters with
existing Yjs infrastructure (y-websocket, Hocuspocus, Liveblocks, a custom
gateway) can collaborate without the native relay — and get **field-level merge**
for concurrent edits to the same element.

This is **not** a change to the canonical engine. The canonical collaboration
backend is element-LWW (see [collaboration](../collaboration/spec.md)), shared
byte-identically with the Swift twin and locked by `Fixtures/protocol/*.json`.
This spec describes the **mapping invariants** of the Yjs backend so a
Yjs-synced scene stays a valid `.excalidraw` and interoperates with the LWW
engine. The adapter is **web-only** and the core library takes no `yjs`
dependency.

Implemented by `@cyberdynecorp/excalidraw-yjs` (`YjsCollab`, the element ↔ Y.Doc
mapping), wired to `@cyberdynecorp/excalidraw-svelte`'s `EditorStore` via its
additive `onChange` / `applyExternalElements` hooks.
(src: web/packages/excalidraw-yjs/, web/packages/excalidraw-svelte/src/svelte/editor-store.ts)

## Requirements

### Requirement: Id-keyed per-element map

The system SHALL represent the scene as a top-level `Y.Map` keyed by element id,
whose values are a per-element `Y.Map` of that element's fields, so that
concurrent edits to *different fields of the same element* merge rather than
clobber.

#### Scenario: Field-level merge
- GIVEN two peers sharing one element
- WHEN one peer edits a scalar field (e.g. `strokeColor`) and the other
  concurrently edits a different scalar field (e.g. `x`)
- THEN after the peers exchange updates BOTH changes SHALL survive on every peer.

#### Scenario: Convergence is order-independent
- GIVEN two peers that each applied disjoint edits
- WHEN their updates are exchanged in either order
- THEN both peers SHALL converge to the same scene.

### Requirement: Soft-delete tombstones

The system SHALL delete elements by setting the `isDeleted` flag and SHALL NOT
hard-remove the per-element `Y.Map` entry, matching the model's soft-delete.

#### Scenario: Delete vs concurrent edit
- GIVEN two peers sharing one element
- WHEN one peer deletes it while the other concurrently edits it
- THEN the peers SHALL converge to a tombstone (`isDeleted = true`) with the
  element's map entry still present.

### Requirement: Fractional index is the z-order source of truth

The system SHALL order elements by the fractional `index` field, never by
`Y.Map` iteration order.

#### Scenario: Concurrent inserts converge to a stable order
- GIVEN two peers that concurrently insert elements with distinct `index` values
- WHEN their updates are exchanged
- THEN every peer SHALL order all elements by `index`, yielding the same order.

### Requirement: File-format and cross-engine fidelity

The system SHALL carry `version` / `versionNonce` on each element (updated on
local mutation but not used by Yjs to reconcile) so that a Yjs-synced scene
round-trips `.excalidraw` and interoperates with the element-LWW engine.

#### Scenario: Round-trip identity
- GIVEN any scene of canonical elements
- WHEN it is written to a `Y.Doc` and read back
- THEN the reconstructed elements SHALL equal the originals (modulo the
  `updated` timestamp).

#### Scenario: LWW interoperability
- GIVEN a scene produced by the Yjs adapter
- WHEN it is reconciled by the element-LWW engine against an empty local scene
- THEN every element SHALL be preserved unchanged.

### Requirement: No core coupling

The canonical core library (`@cyberdynecorp/excalidraw-svelte`) SHALL declare no
`yjs` dependency of any kind, and its built output SHALL NOT import `yjs`.

#### Scenario: Core dependency graph is Yjs-free
- WHEN the core package's dependency manifest and built collaboration entrypoint
  are inspected
- THEN neither SHALL reference `yjs`.

### Requirement: v1 atomic arrays

The system SHALL store array/object fields (`points`, `groupIds`,
`boundElements`, `pressures`, bindings, `customData`) as atomic values in v1
(whole-value last-writer-wins within Yjs), and this limitation SHALL be
documented.

#### Scenario: Concurrent array edits do not corrupt
- GIVEN two peers that concurrently edit the same array field of one element
- WHEN their updates are exchanged
- THEN the field SHALL hold one peer's complete value (never an interleaved or
  partial array).
