import { describe, expect, it } from "vitest";
import { decodeElement, encodeElement } from "./element-codec.js";
import { defaultBase, defaultTextProps } from "./element.js";
import type { ExcalidrawElement } from "./element.js";
import { semanticEqual } from "./json.js";

function assertRoundTrips(el: ExcalidrawElement): void {
  const decoded = decodeElement(encodeElement(el));
  expect(semanticEqual(el, decoded)).toBe(true);
  expect(decoded.type).toBe(el.type);
}

describe("element coding round-trips", () => {
  it("generic shapes", () => {
    for (const type of [
      "rectangle",
      "diamond",
      "ellipse",
      "selection",
      "embeddable",
      "iframe",
    ] as const) {
      assertRoundTrips({ ...defaultBase("g"), type });
    }
  });

  it("text", () => {
    assertRoundTrips({
      ...defaultBase("t"),
      type: "text",
      ...defaultTextProps({
        fontSize: 28,
        fontFamily: 1,
        text: "Hi\nthere",
        textAlign: "center",
        verticalAlign: "middle",
        containerId: "rect-1",
        originalText: "Hi\nthere",
        autoResize: false,
        lineHeight: 1.2,
      }),
    });
  });

  it("freedraw", () => {
    assertRoundTrips({
      ...defaultBase("f"),
      type: "freedraw",
      points: [
        [0, 0],
        [3, 4],
        [10, 2],
      ],
      pressures: [0.1, 0.5, 0.9],
      simulatePressure: false,
    });
  });

  it("line with arrowheads", () => {
    assertRoundTrips({
      ...defaultBase("l"),
      type: "line",
      points: [
        [0, 0],
        [50, 0],
      ],
      startBinding: null,
      endBinding: null,
      startArrowhead: "dot",
      endArrowhead: "triangle_outline",
      polygon: true,
    });
  });

  it("bound arrow", () => {
    assertRoundTrips({
      ...defaultBase("ar"),
      type: "arrow",
      points: [
        [0, 0],
        [20, 20],
      ],
      startBinding: { elementId: "a", fixedPoint: [0.5, 0.5], mode: "inside" },
      endBinding: { elementId: "b", fixedPoint: [0, 1], mode: "orbit" },
      startArrowhead: null,
      endArrowhead: "arrow",
      elbowed: false,
    });
  });

  it("elbow arrow", () => {
    assertRoundTrips({
      ...defaultBase("el"),
      type: "arrow",
      points: [
        [0, 0],
        [20, 0],
        [20, 20],
      ],
      startBinding: null,
      endBinding: null,
      startArrowhead: null,
      endArrowhead: null,
      elbowed: true,
      fixedSegments: [{ start: [20, 0], end: [20, 20], index: 1 }],
      startIsSpecial: false,
      endIsSpecial: true,
    });
  });

  it("image", () => {
    assertRoundTrips({
      ...defaultBase("im"),
      type: "image",
      fileId: "file-1",
      status: "saved",
      scale: [-1, 1],
      crop: { x: 1, y: 2, width: 3, height: 4, naturalWidth: 5, naturalHeight: 6 },
    });
  });

  it("frame and magicframe", () => {
    assertRoundTrips({ ...defaultBase("fr"), type: "frame", name: "Frame 1" });
    assertRoundTrips({ ...defaultBase("mf"), type: "magicframe", name: null });
  });

  it("base properties and customData", () => {
    assertRoundTrips({
      ...defaultBase("x", {
        roundness: { type: 3 },
        boundElements: [{ id: "t1", type: "text" }],
        groupIds: ["g1", "g2"],
        link: "https://example.com",
        locked: true,
        customData: { foo: "bar", n: 42, flag: true },
      }),
      type: "rectangle",
    });
  });
});
