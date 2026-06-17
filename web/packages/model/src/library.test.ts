import { describe, expect, it } from "vitest";
import { defaultBase } from "./element.js";
import type { ExcalidrawElement } from "./element.js";
import { decodeLibrary, encodeLibrary } from "./library.js";
import { SceneDocument } from "./scene-document.js";
import { fixture } from "./test-fixtures.js";

describe("library", () => {
  it("decodes the v1 fixture", () => {
    const library = decodeLibrary(fixture("fixture_library.excalidrawlib"));
    expect(library.items.length).toBeGreaterThan(0);
    expect(library.items[0]!.length).toBeGreaterThan(0);
    expect(library.items[0]![0]!.id).toBe("A");
  });

  it("encodes v2 and round-trips", () => {
    const rect: ExcalidrawElement = {
      ...defaultBase("a", { width: 50, height: 30 }),
      type: "rectangle",
    };
    const reloaded = decodeLibrary(encodeLibrary({ items: [[rect]] }));
    expect(reloaded.items.length).toBe(1);
    expect(reloaded.items[0]![0]!.id).toBe("a");
  });

  it("encoded form is v2", () => {
    const json = encodeLibrary({ items: [[]] });
    expect(json).toContain('"excalidrawlib"');
    expect(json).toContain("libraryItems");
  });

  it("empty library", () => {
    expect(decodeLibrary('{"type":"excalidrawlib","version":2}').items).toEqual([]);
  });
});

describe("SceneDocument", () => {
  it("decodes a fixture and re-encodes as a fixed point", () => {
    const scene = SceneDocument.decode(fixture("minimal_scene.excalidraw"));
    expect(scene.visibleElements.length).toBe(2);
    const once = SceneDocument.encode(scene);
    const twice = SceneDocument.encode(SceneDocument.decode(once));
    expect(once).toBe(twice);
  });
});
