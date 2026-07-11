import { describe, expect, it } from "vitest";
import { Scene } from "../model/index.js";
import { type RenderContext, renderScene } from "./scene-renderer.js";
import { rect } from "./test-helpers.js";
import { themeColor } from "./theme-color.js";
import { Viewport } from "./viewport.js";

function luminance(hex: string): number {
  const v = (o: number) => Number.parseInt(hex.slice(o, o + 2), 16) / 255;
  return 0.2126 * v(1) + 0.7152 * v(3) + 0.0722 * v(5);
}

describe("themeColor", () => {
  it("is the identity in light theme", () => {
    expect(themeColor("#1e1e1e", "light")).toBe("#1e1e1e");
    expect(themeColor("transparent", "light")).toBe("transparent");
  });

  it("maps the default near-black ink to a light grey in dark theme", () => {
    // Greys are hue-invariant, so dark mapping is pure invert(93%):
    // 0x1e (30/255) → 0.93 − 0.86·0.1176 ≈ 0.829 → #d3d3d3.
    expect(themeColor("#1e1e1e", "dark")).toBe("#d3d3d3");
    expect(luminance(themeColor("#1e1e1e", "dark"))).toBeGreaterThan(0.6);
  });

  it("maps white to the dark canvas tone and keeps hues recognisable", () => {
    expect(themeColor("#ffffff", "dark")).toBe("#121212");
    // The default excalidraw red stays red-dominant after the 180° hue spin.
    const red = themeColor("#e03131", "dark");
    const r = Number.parseInt(red.slice(1, 3), 16);
    const g = Number.parseInt(red.slice(3, 5), 16);
    expect(r).toBeGreaterThan(g);
    expect(luminance(red)).toBeGreaterThan(luminance("#e03131"));
  });

  it("passes non-hex values through and preserves alpha digits", () => {
    expect(themeColor("transparent", "dark")).toBe("transparent");
    expect(themeColor("#1e1e1e80", "dark")).toBe("#d3d3d380");
    expect(themeColor("#1e18", "dark").endsWith("88")).toBe(true); // #rgba keeps aa
  });
});

/** Minimal recording context that logs every strokeStyle/fillStyle assignment. */
class StyleRecorder implements RenderContext {
  strokes: string[] = [];
  fills: string[] = [];
  private strokeValue = "";
  private fillValue = "";
  get strokeStyle(): string {
    return this.strokeValue;
  }
  set strokeStyle(v: string) {
    this.strokeValue = v;
    this.strokes.push(v);
  }
  get fillStyle(): string {
    return this.fillValue;
  }
  set fillStyle(v: string) {
    this.fillValue = v;
    this.fills.push(v);
  }
  lineWidth = 1;
  lineCap: CanvasLineCap = "butt";
  lineJoin: CanvasLineJoin = "miter";
  globalAlpha = 1;
  font = "";
  save() {}
  restore() {}
  translate() {}
  scale() {}
  rotate() {}
  beginPath() {}
  moveTo() {}
  lineTo() {}
  bezierCurveTo() {}
  quadraticCurveTo() {}
  closePath() {}
  fill() {}
  stroke() {}
  fillRect() {}
  strokeRect() {}
  arc() {}
  setLineDash() {}
  fillText() {}
  drawImage() {}
}

describe("dark-theme scene rendering", () => {
  const opts = (theme: "light" | "dark") => ({
    viewport: new Viewport(),
    width: 400,
    height: 300,
    theme,
  });

  it("paints a default-ink shape with a light stroke in dark theme", () => {
    // Default stroke is the canonical near-black ink #1e1e1e.
    const scene = new Scene([rect({ x: 10, y: 10, w: 100, h: 80 })]);
    const dark = new StyleRecorder();
    renderScene(dark, scene, opts("dark"));
    expect(dark.strokes).toContain("#d3d3d3");
    expect(dark.strokes).not.toContain("#1e1e1e");
  });

  it("the background override paints a custom colour or nothing at all", () => {
    const scene = new Scene([rect({ x: 10, y: 10, w: 100, h: 80 })]);
    const custom = new StyleRecorder();
    renderScene(custom, scene, { ...opts("light"), background: "#123456" });
    expect(custom.fills[0]).toBe("#123456");

    const transparent = new StyleRecorder();
    const fillRects: number[] = [];
    transparent.fillRect = () => {
      fillRects.push(1);
    };
    renderScene(transparent, scene, { ...opts("light"), background: "transparent" });
    expect(fillRects).toHaveLength(0); // no background fill at all
  });

  it("draws a grid only when a grid size is given", () => {
    const scene = new Scene([rect({ x: 10, y: 10, w: 100, h: 80 })]);
    const without = new StyleRecorder();
    renderScene(without, scene, opts("light"));
    const withGrid = new StyleRecorder();
    renderScene(withGrid, scene, { ...opts("light"), gridSize: 20 });
    // The grid adds its own stroke colour to the pass.
    expect(without.strokes).not.toContain("#00000012");
    expect(withGrid.strokes).toContain("#00000012");
  });

  it("keeps light-theme painting canonical and never mutates the model", () => {
    const scene = new Scene([rect({ x: 10, y: 10, w: 100, h: 80 })]);
    const light = new StyleRecorder();
    renderScene(light, scene, opts("light"));
    expect(light.strokes).toContain("#1e1e1e");

    renderScene(new StyleRecorder(), scene, opts("dark"));
    expect(scene.visibleElements[0]!.strokeColor).toBe("#1e1e1e");
  });
});
