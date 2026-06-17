import type { ExcalidrawElement } from "./element.js";
import { ExcalidrawSchema } from "./enums.js";
import type { ExcalidrawFile } from "./file.js";

/**
 * Minimal fractional-index key support. Fixed-width base-36 keys sort
 * lexicographically in the same order as their numeric position. (parity:
 * Restore.swift / FractionalIndex)
 */
export function fractionalIndexKey(position: number): string {
  const digits = position.toString(36);
  const padded = "0".repeat(Math.max(0, 7 - digits.length)) + digits;
  return `a${padded}`;
}

/** Ensure every element carries a fractional `index`; existing keys are kept. */
function assignMissingIndices(elements: ExcalidrawElement[]): ExcalidrawElement[] {
  if (!elements.some((el) => el.index === null)) return elements;
  return elements.map((el, i) =>
    el.index === null ? { ...el, index: fractionalIndexKey(i) } : el,
  );
}

function restoreElements(elements: ExcalidrawElement[]): ExcalidrawElement[] {
  return assignMissingIndices(elements);
}

/**
 * Load-time normalisation, the counterpart to `restore.ts`. The single entry
 * point all loaded files pass through: canonicalise the envelope and backfill
 * missing element indices. (parity: Restore.swift)
 */
export function restore(file: ExcalidrawFile): ExcalidrawFile {
  return {
    ...file,
    type: ExcalidrawSchema.fileType,
    version:
      file.version < ExcalidrawSchema.schemaVersion ? ExcalidrawSchema.schemaVersion : file.version,
    elements: restoreElements(file.elements),
  };
}
