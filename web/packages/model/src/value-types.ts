import type { BindMode } from "./enums.js";

/** A 2D point in `.excalidraw` wire form: a two-element `[x, y]` array. */
export type LocalPoint = [number, number];

/** Arbitrary JSON value, used for `customData` and unmodelled extras. */
export type JSONValue =
  | null
  | boolean
  | number
  | string
  | JSONValue[]
  | { [key: string]: JSONValue };

/** Corner rounding descriptor (`roundness: { type, value? } | null`). */
export interface Roundness {
  type: number;
  value?: number;
}

/** Reference to an element bound to this one (`BoundElement`). */
export interface BoundElement {
  id: string;
  type: "arrow" | "text";
}

/** Arrow-to-shape binding in the current `fixedPoint` + `mode` form. */
export interface FixedPointBinding {
  elementId: string;
  fixedPoint: LocalPoint;
  mode: BindMode;
}

/** A user-pinned segment of an elbow arrow (`FixedSegment`). */
export interface FixedSegment {
  start: LocalPoint;
  end: LocalPoint;
  index: number;
}

/** Image crop rectangle in natural-image coordinates (`ImageCrop`). */
export interface ImageCrop {
  x: number;
  y: number;
  width: number;
  height: number;
  naturalWidth: number;
  naturalHeight: number;
}

/** A persisted image/binary referenced by an image element (`BinaryFileData`). */
export interface BinaryFileData {
  mimeType: string;
  id: string;
  dataURL: string;
  created: number;
  lastRetrieved?: number;
  version?: number;
}

/**
 * Editor state carried in a `.excalidraw` file. Only a subset of the runtime
 * AppState is persisted and it varies by export source, so we keep the raw
 * key/value bag verbatim (lossless round-trip).
 */
export type AppState = Record<string, JSONValue>;

export function viewBackgroundColor(appState: AppState): string | undefined {
  const value = appState.viewBackgroundColor;
  return typeof value === "string" ? value : undefined;
}

export function gridModeEnabled(appState: AppState): boolean | undefined {
  const value = appState.gridModeEnabled;
  return typeof value === "boolean" ? value : undefined;
}
