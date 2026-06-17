import { describe, expect, it } from "vitest";
import { decodeElement } from "./element-codec.js";
import { decodeFile } from "./file.js";

const decode = (json: string) => decodeElement(JSON.parse(json));

describe("lenient decoding", () => {
  it("rectangle with only type and id gets defaults", () => {
    const el = decode('{"type":"rectangle","id":"r"}');
    expect(el.strokeColor).toBe("#1e1e1e");
    expect(el.backgroundColor).toBe("transparent");
    expect(el.fillStyle).toBe("solid");
    expect(el.strokeWidth).toBe(2);
    expect(el.opacity).toBe(100);
    expect(el.roughness).toBe(1);
    expect(el.version).toBe(1);
    expect(el.groupIds).toEqual([]);
    expect(el.locked).toBe(false);
    expect(el.roundness).toBeNull();
  });

  it("text with defaults", () => {
    const el = decode('{"type":"text","id":"t"}');
    expect(el.type).toBe("text");
    if (el.type === "text") {
      expect(el.fontSize).toBe(20);
      expect(el.fontFamily).toBe(5);
      expect(el.textAlign).toBe("left");
      expect(el.verticalAlign).toBe("top");
      expect(el.autoResize).toBe(true);
      expect(el.lineHeight).toBe(1.25);
    }
  });

  it("line/arrow/freedraw/image defaults", () => {
    const line = decode('{"type":"line","id":"l"}');
    if (line.type === "line") {
      expect(line.points).toEqual([]);
      expect(line.polygon).toBe(false);
      expect(line.startArrowhead).toBeNull();
    }
    const arrow = decode('{"type":"arrow","id":"a"}');
    if (arrow.type === "arrow") expect(arrow.elbowed).toBe(false);
    const free = decode('{"type":"freedraw","id":"f"}');
    if (free.type === "freedraw") {
      expect(free.pressures).toEqual([]);
      expect(free.simulatePressure).toBe(true);
    }
    const image = decode('{"type":"image","id":"i"}');
    if (image.type === "image") {
      expect(image.status).toBe("pending");
      expect(image.scale).toEqual([1, 1]);
      expect(image.fileId).toBeNull();
    }
  });

  it("frame defaults and embeddable", () => {
    const frame = decode('{"type":"frame","id":"fr"}');
    if (frame.type === "frame") expect(frame.name).toBeNull();
    expect(decode('{"type":"embeddable","id":"e"}').type).toBe("embeddable");
  });

  it("file decodes empty object with defaults", () => {
    const file = decodeFile("{}");
    expect(file.type).toBe("excalidraw");
    expect(file.version).toBe(2);
    expect(file.source).toBe("unknown");
    expect(file.elements).toEqual([]);
    expect(file.files).toEqual({});
  });

  it("non-object appState falls back to empty", () => {
    const file = decodeFile('{"appState":[1,2,3]}');
    expect(file.appState).toEqual({});
  });

  it("unknown element type throws", () => {
    expect(() => decode('{"type":"unknownThing","id":"z"}')).toThrow();
  });
});
