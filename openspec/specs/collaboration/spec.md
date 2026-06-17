# Collaboration

## Purpose

Real-time multi-client editing of one shared scene over a custom WebSocket
protocol, so an iOS/iPad (Swift) client and a web (Svelte) client edit the same
room live. The wire schema and the element-reconciliation rule are
language-neutral and implemented identically on both clients (TS: `@xs/protocol`,
ported faithfully into the Swift client), so the two converge without a central
authority or CRDT. (src: web/packages/protocol/)

## Requirements

### Requirement: Versioned element reconciliation

The system SHALL resolve concurrent edits to the same element by a deterministic,
symmetric last-writer-wins rule over the model's `version` / `versionNonce`
fields, so that every client converges on the same element regardless of which
copy it held locally.

#### Scenario: Higher version wins
- GIVEN a local element and a remote element with the same `id`
- WHEN their `version` numbers differ
- THEN the element with the higher `version` SHALL be kept.

#### Scenario: Version tie broken by versionNonce
- GIVEN a local and remote element with the same `id` and equal `version`
- WHEN their `versionNonce` values differ
- THEN the element with the lower `versionNonce` SHALL be kept.

#### Scenario: Symmetric convergence
- GIVEN two peers that each hold one of the two conflicting copies locally and
  receive the other
- WHEN each applies the reconciliation rule
- THEN both peers SHALL select the same winning element.

#### Scenario: Deletion races
- GIVEN a soft-delete (`isDeleted = true`) carries a bumped `version` like any
  other edit
- WHEN a delete races a concurrent edit of the same element
- THEN the reconciliation rule SHALL resolve it by `version` / `versionNonce`,
  identically on both clients.

#### Scenario: Merge a remote batch
- WHEN a client reconciles an incoming batch of remote elements against its
  local set
- THEN local-only elements SHALL be preserved, remote-only elements SHALL be
  added, and same-id conflicts SHALL be resolved by the rule above.

### Requirement: Wire protocol

The system SHALL define a versioned message schema carried as JSON over a raw
WebSocket, covering room membership, presence, live pointers, element sync, and
liveness. Each message SHALL be discriminated by a string `type` tag, and a
decoder SHALL reject malformed JSON and unknown message types.

#### Scenario: Protocol version is advertised
- WHEN a client `join`s a room
- THEN it SHALL send the `protocol` version, and the relay SHALL echo it in the
  `room-state` reply so a mismatch can be detected.

#### Scenario: Late joiner receives the scene
- WHEN a client joins a room
- THEN the relay SHALL send a `room-state` message containing the current peer
  roster and the latest scene elements.

#### Scenario: Element edits propagate as versioned deltas
- WHEN a client mutates elements
- THEN it SHALL broadcast an `element-updates` message carrying the changed
  elements with their `version` / `versionNonce`, which receivers reconcile.

#### Scenario: Presence and pointers
- WHEN a client's cursor, selection, or active tool changes
- THEN it SHALL broadcast `presence` (throttled) and MAY stream `pointer`
  (high-frequency, lossy) so peers can render each other's cursors and selection.

#### Scenario: Rejecting garbage
- WHEN a decoder receives invalid JSON or an object whose `type` is not a known
  message type
- THEN it SHALL raise a protocol error rather than act on the data.
