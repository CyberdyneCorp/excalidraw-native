import { describe, expect, it } from "vitest";
import { defaultBase } from "./element.js";
import type { ExcalidrawElement } from "./element.js";
import { makeFile } from "./file.js";
import { restore } from "./restore.js";
import { Scene } from "./scene.js";
import { gridModeEnabled, viewBackgroundColor } from "./value-types.js";

function el(id: string, index: string | null): ExcalidrawElement {
  return { ...defaultBase(id, { index }), type: "rectangle" };
}

describe("restore", () => {
  it("assigns missing indices in document order", () => {
    const file = makeFile({ elements: [el("a", null), el("b", null), el("c", null)] });
    const indices = restore(file).elements.map((e) => e.index);
    expect(indices.includes(null)).toBe(false);
    expect(indices).toEqual([...(indices as string[])].sort());
  });

  it("preserves existing indices", () => {
    const restored = restore(makeFile({ elements: [el("a", "a0"), el("b", null)] }));
    expect(restored.elements[0]!.index).toBe("a0");
    expect(restored.elements[1]!.index).not.toBeNull();
  });

  it("upgrades version and type", () => {
    const restored = restore(makeFile({ type: "x", version: 1, elements: [] }));
    expect(restored.type).toBe("excalidraw");
    expect(restored.version).toBe(2);
  });
});

describe("Scene", () => {
  it("lookup, add, remove", () => {
    const scene = new Scene([el("a", "a0")]);
    expect(scene.element("a")).toBeDefined();
    scene.add(el("b", "a1"));
    expect(scene.visibleElements.length).toBe(2);

    expect(scene.remove("a")).toBe(true);
    expect(scene.visibleElements.length).toBe(1);
    expect(scene.element("a")?.isDeleted).toBe(true);
    expect(scene.remove("missing")).toBe(false);
  });

  it("mutate bumps version and nonce", () => {
    const scene = new Scene([el("a", "a0")]);
    scene.mutate(
      "a",
      (e) => {
        e.opacity = 50;
      },
      { versionNonce: 999 },
    );
    const updated = scene.element("a");
    expect(updated?.opacity).toBe(50);
    expect(updated?.version).toBe(2);
    expect(updated?.versionNonce).toBe(999);
  });

  it("app-state accessors and passthrough", () => {
    const appState = { viewBackgroundColor: "#fff", gridModeEnabled: true, unknownKey: [1, 2] };
    expect(viewBackgroundColor(appState)).toBe("#fff");
    expect(gridModeEnabled(appState)).toBe(true);
    expect(appState.unknownKey).toEqual([1, 2]);
  });
});
