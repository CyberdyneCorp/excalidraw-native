import { type ExcalidrawElement, defaultBase } from "@cyberdynecorp/excalidraw-svelte/model";
import * as Y from "yjs";
import { type YElement, type YElements, syncElementsToDoc } from "./mapping.js";

/** A minimal rectangle element for tests (flat model shape). */
export function rect(id: string, overrides: Partial<ExcalidrawElement> = {}): ExcalidrawElement {
  return {
    ...defaultBase(id, { width: 100, height: 60, index: "a0", ...overrides }),
    type: "rectangle",
  } as ExcalidrawElement;
}

/** Bump an element as a local mutation would (new version + nonce). */
export function edit(
  el: ExcalidrawElement,
  overrides: Partial<ExcalidrawElement>,
): ExcalidrawElement {
  return {
    ...el,
    ...overrides,
    version: el.version + 1,
    versionNonce: el.versionNonce + 1,
  } as ExcalidrawElement;
}

/** `updated` is a wall-clock timestamp; drop it before structural comparison. */
export function stripUpdated(el: ExcalidrawElement): Record<string, unknown> {
  const { updated: _updated, ...rest } = el as unknown as Record<string, unknown>;
  return rest;
}

export function elementsKey(doc: Y.Doc): YElements {
  return doc.getMap<YElement>("elements");
}

/** Seed a fresh doc with elements (non-local origin). */
export function seed(elements: ExcalidrawElement[]): Y.Doc {
  const doc = new Y.Doc();
  syncElementsToDoc(doc, elementsKey(doc), elements, "seed", Y.Map);
  return doc;
}

/** Apply `elements` to a doc as a discrete edit (non-local origin). */
export function applyEdit(doc: Y.Doc, elements: ExcalidrawElement[]): void {
  syncElementsToDoc(doc, elementsKey(doc), elements, "edit", Y.Map);
}

/** Exchange full state between two docs so both converge. */
export function exchange(a: Y.Doc, b: Y.Doc): void {
  const ua = Y.encodeStateAsUpdate(a);
  const ub = Y.encodeStateAsUpdate(b);
  Y.applyUpdate(b, ua);
  Y.applyUpdate(a, ub);
}
