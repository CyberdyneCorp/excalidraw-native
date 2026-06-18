import type { ExcalidrawElement } from "@cyberdynecorp/excalidraw-svelte/model";
import type * as Y from "yjs";

/**
 * Element ↔ Y.Doc mapping (issue #11).
 *
 * The scene is a top-level `Y.Map` keyed by element id, each value a per-element
 * `Y.Map` of that element's fields. Storing a `Y.Map` per element (not a
 * `Y.Array`) is what lets Yjs merge *different fields of the same element* — the
 * headline win over element-LWW (one peer recolors while another moves).
 *
 * v1 field rules:
 * - **Scalars** (`x`, `y`, `strokeColor`, `version`, `index`, …) → plain values
 *   in the element's `Y.Map`; concurrent edits to different keys merge.
 * - **Arrays/objects** (`points`, `groupIds`, `boundElements`, `pressures`,
 *   `roundness`, bindings, `customData`) → stored as atomic JSON values (whole-
 *   value LWW within Yjs). Collaborative point-level editing is a future tier.
 * - **Soft delete**: `isDeleted` is a CRDT flag; the per-element `Y.Map` is never
 *   hard-removed (tombstone), matching Excalidraw's soft-delete model.
 * - **Z-order**: the fractional `index` field is the source of truth, never the
 *   `Y.Map` iteration order.
 * - `version`/`versionNonce` are carried (not used to reconcile — Yjs does) so a
 *   Yjs-synced scene still round-trips `.excalidraw` and the LWW engine.
 */

/** A per-element field map: `id -> (field -> value)`. */
export type YElement = Y.Map<unknown>;
export type YElements = Y.Map<YElement>;

type Fields = Record<string, unknown>;

/** Structural equality used for field-level change detection. */
function valueEquals(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a === null || b === null || typeof a !== "object" || typeof b !== "object") return false;
  // Arrays/objects are stored atomically; compare by canonical JSON.
  return JSON.stringify(a) === JSON.stringify(b);
}

/**
 * Write an element's fields into its `Y.Map`, setting only the keys whose value
 * changed and removing keys no longer present (e.g. after a type change). Caller
 * must run this inside a `Y.Transaction`. `undefined` values are skipped (Yjs
 * cannot store `undefined`; an absent key reads back as `undefined`).
 */
export function writeElementFields(yEl: YElement, element: ExcalidrawElement): void {
  const fields = element as unknown as Fields;
  const seen = new Set<string>();
  for (const [key, value] of Object.entries(fields)) {
    if (value === undefined) continue;
    seen.add(key);
    if (!valueEquals(yEl.get(key), value)) yEl.set(key, value);
  }
  for (const key of [...yEl.keys()]) {
    if (!seen.has(key)) yEl.delete(key);
  }
}

/** Reconstruct an `ExcalidrawElement` from its `Y.Map`. */
export function readElementFields(yEl: YElement): ExcalidrawElement {
  return Object.fromEntries(yEl.entries()) as unknown as ExcalidrawElement;
}

/** Lexicographic compare on the fractional `index` (the z-order source of truth). */
function byIndex(a: ExcalidrawElement, b: ExcalidrawElement): number {
  const ai = a.index ?? "";
  const bi = b.index ?? "";
  if (ai < bi) return -1;
  if (ai > bi) return 1;
  // Stable tiebreak so equal/absent indices converge to the same order.
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

/**
 * Read the whole scene from the doc, ordered by the fractional `index` field
 * (never `Y.Map` iteration order). Includes soft-deleted tombstones — the model
 * carries `isDeleted` elements; the renderer/`visibleElements` filters them.
 */
export function readDocElements(yElements: YElements): ExcalidrawElement[] {
  const elements: ExcalidrawElement[] = [];
  for (const yEl of yElements.values()) elements.push(readElementFields(yEl));
  elements.sort(byIndex);
  return elements;
}

/**
 * Mirror `elements` into the doc inside a single transaction tagged with
 * `origin`: upsert each element's `Y.Map` (creating it on first sight) and
 * write changed fields; ids present in the doc but absent from `elements` are
 * tombstoned (`isDeleted = true`), never hard-removed. The `YElementCtor` is
 * `Y.Map` passed by the caller so this module needs no direct `yjs` import at
 * runtime (keeps the dependency a peer).
 */
export function syncElementsToDoc(
  doc: Y.Doc,
  yElements: YElements,
  elements: readonly ExcalidrawElement[],
  origin: unknown,
  YMapCtor: new () => YElement,
): void {
  doc.transact(() => {
    const incoming = new Set<string>();
    for (const element of elements) {
      incoming.add(element.id);
      let yEl = yElements.get(element.id);
      if (yEl === undefined) {
        yEl = new YMapCtor();
        yElements.set(element.id, yEl);
      }
      writeElementFields(yEl, element);
    }
    // Tombstone anything the local scene dropped entirely (never hard-delete).
    for (const id of [...yElements.keys()]) {
      if (incoming.has(id)) continue;
      const yEl = yElements.get(id);
      if (yEl !== undefined && yEl.get("isDeleted") !== true) yEl.set("isDeleted", true);
    }
  }, origin);
}
