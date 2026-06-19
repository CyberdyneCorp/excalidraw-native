import { describe, expect, it } from "vitest";
import { Point } from "../math/index.js";
import { type ExcalidrawElement, defaultBase } from "../model/index.js";
import { makeEditor } from "./test-helpers.js";

function rect(id: string, x = 0, y = 0): ExcalidrawElement {
  return { ...defaultBase(id, { x, y, width: 40, height: 40 }), type: "rectangle" };
}

describe("deleteSelected — bound elements", () => {
  it("deletes a sticky note's bound text along with its container (no orphan)", () => {
    const ec = makeEditor([]);
    ec.createStickyNote(new Point(100, 100)); // selects only the container
    expect(ec.scene.visibleElements).toHaveLength(2); // container + bound text

    ec.deleteSelected();

    // Regression: previously only the selected container was removed, leaving
    // the bound text floating on screen with no way to select/delete it.
    expect(ec.scene.visibleElements).toHaveLength(0);
  });

  it("clears dangling bound-element references on survivors", () => {
    // A rectangle that lists a (selected, deleted) arrow in its boundElements.
    const arrow: ExcalidrawElement = {
      ...defaultBase("arrow", { x: 0, y: 0, width: 50, height: 0 }),
      type: "arrow",
      points: [
        [0, 0],
        [50, 0],
      ],
      startBinding: { elementId: "box", fixedPoint: [0, 0], mode: "inside" },
      endBinding: null,
      startArrowhead: null,
      endArrowhead: "arrow",
      elbowed: false,
    };
    const box: ExcalidrawElement = {
      ...rect("box", 60, 0),
      boundElements: [{ id: "arrow", type: "arrow" }],
    };
    const ec = makeEditor([box, arrow]);

    ec.selectedIDs = new Set(["arrow"]);
    ec.deleteSelected();

    const survivor = ec.scene.element("box");
    expect(survivor?.isDeleted).toBe(false);
    // The deleted arrow must not linger in the box's boundElements.
    expect(survivor?.boundElements ?? []).toEqual([]);
  });
});
