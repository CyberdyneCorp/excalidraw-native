import { describe, expect, it } from "vitest";
import { defaultBase } from "./element.js";
import type { ExcalidrawElement } from "./element.js";
import { type ElementChange, SceneDelta, Store } from "./history.js";
import { Scene } from "./scene.js";

function rect(id: string, x = 0): ExcalidrawElement {
  return { ...defaultBase(id, { x }), type: "rectangle" };
}

describe("SceneDelta", () => {
  it("detects changes", () => {
    const a = rect("a");
    const aMoved = { ...a, x: 50 };
    const delta = SceneDelta.between([a], [aMoved]);
    expect(delta.changes.size).toBe(1);
    expect((delta.changes.get("a")?.after as { x: number }).x).toBe(50);
  });

  it("is empty when unchanged", () => {
    const a = rect("a");
    expect(SceneDelta.between([a], [a]).isEmpty).toBe(true);
  });

  it("inverse swaps before/after", () => {
    const delta = SceneDelta.between([rect("a", 0)], [rect("a", 9)]);
    expect((delta.inverse().changes.get("a")?.after as { x: number }).x).toBe(0);
  });
});

describe("Store undo/redo", () => {
  it("undo/redo a move", () => {
    const store = new Store(new Scene([rect("a", 0)]));
    store.transaction((s) => {
      s.mutate("a", (el) => {
        el.x = 100;
      });
    });
    expect(store.scene.element("a")?.x).toBe(100);
    expect(store.canUndo).toBe(true);

    expect(store.undo()).toBe(true);
    expect(store.scene.element("a")?.x).toBe(0);
    expect(store.canRedo).toBe(true);

    expect(store.redo()).toBe(true);
    expect(store.scene.element("a")?.x).toBe(100);
  });

  it("undo of an insertion removes the element", () => {
    const store = new Store(new Scene([rect("a")]));
    store.transaction((s) => s.add(rect("b", 5)));
    expect(store.scene.elements.length).toBe(2);
    expect(store.undo()).toBe(true);
    expect(store.scene.element("b")).toBeUndefined();
    expect(store.scene.elements.length).toBe(1);
    expect(store.redo()).toBe(true);
    expect(store.scene.element("b")).toBeDefined();
  });

  it("a new edit clears the redo stack", () => {
    const store = new Store(new Scene([rect("a", 0)]));
    store.transaction((s) => {
      s.mutate("a", (el) => {
        el.x = 1;
      });
    });
    store.undo();
    expect(store.canRedo).toBe(true);
    store.transaction((s) => {
      s.mutate("a", (el) => {
        el.x = 2;
      });
    });
    expect(store.canRedo).toBe(false);
  });

  it("empty commit does nothing", () => {
    const store = new Store(new Scene([rect("a")]));
    store.commit();
    expect(store.canUndo).toBe(false);
    expect(store.undo()).toBe(false);
    expect(store.redo()).toBe(false);
  });
});

describe("Scene.apply", () => {
  it("preserves element order", () => {
    const scene = new Scene([rect("a"), rect("b"), rect("c")]);
    const bMoved = { ...rect("b", 99), version: 2 };
    scene.apply(
      new SceneDelta(new Map([["b", { before: rect("b"), after: bMoved } as ElementChange]])),
    );
    expect(scene.elements.map((el) => el.id)).toEqual(["a", "b", "c"]);
    expect(scene.element("b")?.x).toBe(99);
  });
});
