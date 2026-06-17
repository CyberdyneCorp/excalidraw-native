import { describe, expect, it } from "vitest";
import { decodeFile, encodeFile } from "./file.js";
import { semanticEqual } from "./json.js";
import { Scene } from "./scene.js";
import { fixture } from "./test-fixtures.js";

describe("file round-trip", () => {
  it("minimal scene is a decode→encode fixed point", () => {
    const src = fixture("minimal_scene.excalidraw");
    const once = encodeFile(decodeFile(src));
    const twice = encodeFile(decodeFile(once));
    expect(once).toBe(twice);
  });

  it("minimal scene is diff-clean against the source (semantic)", () => {
    const src = fixture("minimal_scene.excalidraw");
    const reencoded = encodeFile(decodeFile(src));
    expect(semanticEqual(JSON.parse(src), JSON.parse(reencoded))).toBe(true);
  });

  it("milestone: load, mutate via the API, save back", () => {
    const src = fixture("minimal_scene.excalidraw");
    const scene = Scene.fromFile(decodeFile(src));

    expect(scene.element("rect-1")?.version).toBe(1);
    const didMutate = scene.mutate(
      "rect-1",
      (el) => {
        el.x = 150;
        el.strokeColor = "#e03131";
      },
      { timestamp: 1_700_000_001_000 },
    );
    expect(didMutate).toBe(true);

    const reloaded = Scene.fromFile(decodeFile(encodeFile(scene.toFile())));
    const rect = reloaded.element("rect-1");
    expect(rect?.x).toBe(150);
    expect(rect?.strokeColor).toBe("#e03131");
    expect(rect?.version).toBe(2); // bumped by mutate
    expect(rect?.updated).toBe(1_700_000_001_000);
  });

  it("parses element kinds", () => {
    const file = decodeFile(fixture("minimal_scene.excalidraw"));
    expect(file.elements.length).toBe(2);
    expect(file.elements[0]!.type).toBe("rectangle");
    const text = file.elements[1]!;
    expect(text.type).toBe("text");
    if (text.type === "text") {
      expect(text.text).toBe("Hello");
      expect(text.fontFamily).toBe(5);
    }
  });
});
