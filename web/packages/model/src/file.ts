import { decodeElement, encodeElement } from "./element-codec.js";
import type { ExcalidrawElement } from "./element.js";
import { ExcalidrawSchema } from "./enums.js";
import { canonicalJSON } from "./json.js";
import type { AppState, BinaryFileData } from "./value-types.js";

/** The top-level `.excalidraw` document envelope. (parity: ExcalidrawFile.swift) */
export interface ExcalidrawFile {
  type: string;
  version: number;
  source: string;
  elements: ExcalidrawElement[];
  appState: AppState;
  files: Record<string, BinaryFileData>;
}

export function makeFile(overrides: Partial<ExcalidrawFile> = {}): ExcalidrawFile {
  return {
    type: ExcalidrawSchema.fileType,
    version: ExcalidrawSchema.schemaVersion,
    source: "excalidraw-web",
    elements: [],
    appState: {},
    files: {},
    ...overrides,
  };
}

function plainObject(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

/** Decode a `.excalidraw` document from raw JSON text, leniently. */
export function decodeFile(json: string): ExcalidrawFile {
  const raw = JSON.parse(json) as Record<string, unknown>;
  const elements = Array.isArray(raw.elements)
    ? (raw.elements as Record<string, unknown>[]).map(decodeElement)
    : [];
  return {
    type: typeof raw.type === "string" ? raw.type : ExcalidrawSchema.fileType,
    version: typeof raw.version === "number" ? raw.version : ExcalidrawSchema.schemaVersion,
    source: typeof raw.source === "string" ? raw.source : "unknown",
    elements,
    appState: plainObject(raw.appState) as AppState,
    files: plainObject(raw.files) as Record<string, BinaryFileData>,
  };
}

/**
 * Encode to canonical JSON (sorted keys; 2-space when pretty-printed) so the
 * output is stable and diffable, matching the Swift encoder's `.sortedKeys`.
 */
export function encodeFile(file: ExcalidrawFile, prettyPrinted = true): string {
  return canonicalJSON(
    {
      type: file.type,
      version: file.version,
      source: file.source,
      elements: file.elements.map(encodeElement),
      appState: file.appState,
      files: file.files,
    },
    prettyPrinted,
  );
}
