import { decodeElement, encodeElement } from "./element-codec.js";
import type { ExcalidrawElement } from "./element.js";
import { canonicalJSON } from "./json.js";

/**
 * A reusable library of element groups (`.excalidrawlib`). Reads both the v1
 * shape (`library: [[element, ...], ...]`) and v2 (`libraryItems: [{ elements }]`),
 * and writes v2 (the current Excalidraw format). (parity: ExcalidrawLibrary.swift)
 */
export interface ExcalidrawLibrary {
  /** Each item is a group of elements stamped onto the canvas as a unit. */
  items: ExcalidrawElement[][];
}

export function decodeLibrary(json: string): ExcalidrawLibrary {
  const raw = JSON.parse(json) as Record<string, unknown>;
  const decodeGroup = (group: unknown): ExcalidrawElement[] =>
    Array.isArray(group) ? (group as Record<string, unknown>[]).map(decodeElement) : [];

  if (Array.isArray(raw.library)) {
    return { items: (raw.library as unknown[]).map(decodeGroup) };
  }
  if (Array.isArray(raw.libraryItems)) {
    return {
      items: (raw.libraryItems as { elements?: unknown }[]).map((item) =>
        decodeGroup(item.elements),
      ),
    };
  }
  return { items: [] };
}

export function encodeLibrary(library: ExcalidrawLibrary, prettyPrinted = true): string {
  return canonicalJSON(
    {
      type: "excalidrawlib",
      version: 2,
      libraryItems: library.items.map((elements) => ({
        id: null,
        status: "unpublished",
        created: 0,
        name: null,
        elements: elements.map(encodeElement),
      })),
    },
    prettyPrinted,
  );
}
