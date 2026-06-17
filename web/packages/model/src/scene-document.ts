import { decodeFile, encodeFile } from "./file.js";
import { restore } from "./restore.js";
import { Scene } from "./scene.js";

/**
 * Serialization between a `Scene` and `.excalidraw` document text. Loading
 * always passes through `restore` so older/partial files are canonicalised.
 * (parity: SceneDocument.swift)
 */
export const SceneDocument = {
  fileExtension: "excalidraw",

  encode(scene: Scene, source = "excalidraw-web", prettyPrinted = true): string {
    return encodeFile(scene.toFile(source), prettyPrinted);
  },

  decode(json: string): Scene {
    return Scene.fromFile(restore(decodeFile(json)));
  },
} as const;
