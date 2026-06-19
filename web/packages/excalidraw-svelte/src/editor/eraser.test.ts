import { describe, expect, it } from "vitest";
import { Point } from "../math/index.js";
import { type ExcalidrawElement, defaultBase } from "../model/index.js";
import { pointerEvent } from "./pointer-event.js";
import { makeEditor } from "./test-helpers.js";

/** A horizontal freedraw stroke along y=0 from x=0..100. */
function stroke(id: string): ExcalidrawElement {
  return {
    ...defaultBase(id, { x: 0, y: 0, width: 100, height: 0 }),
    type: "freedraw",
    points: [
      [0, 0],
      [50, 0],
      [100, 0],
    ],
    pressures: [],
    simulatePressure: true,
  } as ExcalidrawElement;
}

describe("eraser hit radius matches the input device", () => {
  it("erases a stroke under a touch (28px) even when a mouse (10px) would miss", () => {
    const ec = makeEditor([stroke("s")]);
    ec.setTool("eraser");
    // 18 units from the stroke: outside the old hardcoded mouse radius (10),
    // inside the touch radius (28). On iPad this is the difference between
    // "can't delete" and erasing normally.
    ec.pointerDown(pointerEvent(new Point(50, 18), "down", { type: "touch" }));
    expect(ec.scene.visibleElements).toHaveLength(0);
  });

  it("a pencil (16px) erases within its radius", () => {
    const ec = makeEditor([stroke("s")]);
    ec.setTool("eraser");
    ec.pointerDown(pointerEvent(new Point(50, 14), "down", { type: "pen" }));
    expect(ec.scene.visibleElements).toHaveLength(0);
  });

  it("does not erase a stroke far outside even the touch radius", () => {
    const ec = makeEditor([stroke("s")]);
    ec.setTool("eraser");
    ec.pointerDown(pointerEvent(new Point(50, 60), "down", { type: "touch" }));
    expect(ec.scene.visibleElements).toHaveLength(1); // 60 > 28, left alone
  });
});
