import { describe, expect, it } from "vitest";
import { defaultOverlayColors } from "../render/index.js";
import { ALL_TOOLS, resolveUIOptions } from "./ui-options.js";

describe("uiOptions", () => {
  it("defaults to the complete editor", () => {
    const ui = resolveUIOptions();
    expect(ui.panel).toBe(true);
    expect(ui.palette).toBe(true);
    expect(ui.toolbar !== false && ui.toolbar.tools).toEqual(ALL_TOOLS);
    expect(ui.menu !== false && ui.menu.export).toBe(true);
    expect(ui.contextMenu !== false && ui.contextMenu.clipboard).toBe(true);
  });

  it("false disables a whole section", () => {
    const ui = resolveUIOptions({ toolbar: false, menu: false, panel: false });
    expect(ui.toolbar).toBe(false);
    expect(ui.menu).toBe(false);
    expect(ui.panel).toBe(false);
    expect(ui.palette).toBe(true); // untouched sections stay on
  });

  it("an object overrides individual fields, keeping the rest", () => {
    const ui = resolveUIOptions({
      toolbar: { tools: ["selection", "rectangle"], lock: false },
      menu: { export: false },
    });
    expect(ui.toolbar !== false && ui.toolbar.tools).toEqual(["selection", "rectangle"]);
    expect(ui.toolbar !== false && ui.toolbar.lock).toBe(false);
    expect(ui.toolbar !== false && ui.toolbar.more).toBe(true); // default kept
    expect(ui.menu !== false && ui.menu.export).toBe(false);
    expect(ui.menu !== false && ui.menu.save).toBe(true); // default kept
  });

  it("overlay colour defaults are the excalidraw-like palette", () => {
    expect(defaultOverlayColors.accent).toBe("#6b82f5");
    expect(defaultOverlayColors.bindingHighlight).toBe("#68b1ec");
  });
});
