import { describe, expect, it } from "vitest";
import { Point } from "../math/index.js";
import { type ExcalidrawElement, Scene, defaultBase, makeFile, restore } from "../model/index.js";
import { EditorController } from "./controller.js";
import { pointerEvent } from "./pointer-event.js";

function rect(id: string, x = 0): ExcalidrawElement {
  return { ...defaultBase(id, { x, y: 0, width: 40, height: 40 }), type: "rectangle" };
}

function drawRect(ec: EditorController, from: Point, to: Point): void {
  ec.setTool("rectangle");
  ec.pointerDown(pointerEvent(from, "down"));
  ec.pointerMove(pointerEvent(to, "move"));
  ec.pointerUp(pointerEvent(to, "up"));
}

describe("element id collisions", () => {
  it("a fresh draw never reuses an id already in a loaded scene", () => {
    // Scene pre-populated as if a `.excalidraw` (or the bundled sample / autosave)
    // was loaded — its ids follow the same el-N scheme the default generator mints.
    const ec = new EditorController(new Scene([rect("el-1"), rect("el-2", 80)]));
    drawRect(ec, new Point(0, 200), new Point(50, 250));

    const ids = ec.scene.visibleElements.map((e) => e.id);
    // Regression: nextID() restarted at el-1 and collided, so scene.add created a
    // SECOND element sharing id "el-1" — which made selection span both (huge
    // box), delete remove only one, and move leave a phantom copy.
    expect(new Set(ids).size).toBe(ids.length); // all ids unique
    expect(ids).toContain("el-1");
    expect(ids).toContain("el-2");
  });

  it("scene.add never creates a second entry for an existing id", () => {
    const scene = new Scene([rect("a")]);
    scene.add({ ...rect("a", 999) }); // same id, different position
    expect(scene.elements.filter((e) => e.id === "a")).toHaveLength(1);
  });

  it("restore heals a corrupted saved scene with duplicate ids (all stay deletable)", () => {
    // A document saved before the fix: two elements share id "el-1".
    const file = makeFile({ elements: [rect("el-1"), { ...rect("el-1"), x: 100 }, rect("el-2")] });
    const restored = restore(file);
    const ids = restored.elements.map((e) => e.id);
    expect(restored.elements).toHaveLength(3); // none dropped
    expect(new Set(ids).size).toBe(3); // all ids unique → all addressable/deletable
    expect(ids[0]).toBe("el-1"); // first occurrence keeps its id
  });
});
