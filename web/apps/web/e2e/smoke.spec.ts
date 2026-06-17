import { expect, test } from "@playwright/test";
import {
  clickCanvas,
  drag,
  elementCount,
  read,
  ready,
  selectedCount,
  selectTool,
  shot,
} from "./helpers.js";

test.beforeEach(async ({ page }) => {
  await page.goto("/");
  await ready(page);
});

test("draws shapes with the drawing tools", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.2, y: 0.25 }, { x: 0.45, y: 0.55 });
  expect(await elementCount(page)).toBe(1);

  await selectTool(page, "ellipse");
  await drag(page, { x: 0.55, y: 0.25 }, { x: 0.78, y: 0.55 });
  expect(await elementCount(page)).toBe(2);

  await selectTool(page, "diamond");
  await drag(page, { x: 0.4, y: 0.65 }, { x: 0.6, y: 0.9 });
  expect(await elementCount(page)).toBe(3);

  await selectTool(page, "arrow");
  await drag(page, { x: 0.45, y: 0.4 }, { x: 0.55, y: 0.4 });
  expect(await elementCount(page)).toBe(4);
  // The arrow must carry an end arrowhead so the renderer draws the head.
  expect(
    await read(page, (s) =>
      s.scene.visibleElements.some((e) => e.type === "arrow" && e.endArrowhead === "arrow"),
    ),
  ).toBe(true);

  await shot(page, "01-shapes");
});

test("selects, transforms, duplicates, and undoes", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.2, y: 0.3 }, { x: 0.4, y: 0.5 });
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.55, y: 0.3 }, { x: 0.75, y: 0.5 });
  expect(await elementCount(page)).toBe(2);

  // Box-select both with a marquee from empty space.
  await selectTool(page, "selection");
  await drag(page, { x: 0.1, y: 0.15 }, { x: 0.9, y: 0.7 });
  expect(await selectedCount(page)).toBe(2);
  await shot(page, "02-selection");

  await page.getByTestId("duplicate").click();
  expect(await elementCount(page)).toBe(4);

  await page.getByTestId("undo").click();
  expect(await elementCount(page)).toBe(2);
  await page.getByTestId("redo").click();
  expect(await elementCount(page)).toBe(4);
});

test("inserts the generators (table, sticky note, chart, mermaid)", async ({ page }) => {
  await page.getByTestId("gen-table").click();
  expect(await elementCount(page)).toBe(18); // 3×3 cells + labels

  await page.getByTestId("gen-note").click();
  expect(await read(page, (s) => s.scene.visibleElements.some((e) => e.backgroundColor === "#ffec99"))).toBe(
    true,
  );
  // Inserting a sticky note opens its text editor; typing must land on the bound text.
  const noteEditor = page.getByTestId("text-editor");
  await expect(noteEditor).toBeVisible();
  await noteEditor.fill("Idea!");
  await noteEditor.press("Enter");
  expect(
    await read(page, (s) =>
      s.scene.visibleElements.some((e) => e.type === "text" && e.containerId !== null && e.text === "Idea!"),
    ),
  ).toBe(true);

  await page.getByTestId("gen-chart").click();
  await page.getByTestId("gen-mermaid").click();
  // Mermaid produces shapes + bound text + arrows.
  expect(await read(page, (s) => s.scene.visibleElements.some((e) => e.type === "arrow"))).toBe(true);
  await shot(page, "03-generators");
});

test("types on-canvas text", async ({ page }) => {
  await selectTool(page, "text");
  await clickCanvas(page, { x: 0.35, y: 0.4 });
  // The text tool placed an editor in the store; the app shows a textarea.
  expect(await read(page, (s) => (s as unknown as { editingText: unknown }).editingText !== null)).toBe(
    true,
  );
  const editor = page.getByTestId("text-editor");
  await expect(editor).toBeVisible();
  await editor.fill("Hello web");
  await editor.press("Enter");
  expect(
    await read(page, (s) => s.scene.visibleElements.some((e) => e.type === "text" && e.text === "Hello web")),
  ).toBe(true);
  await shot(page, "04-text");
});

test("the laser pointer paints a trail without creating elements", async ({ page }) => {
  await selectTool(page, "laser");
  await drag(page, { x: 0.3, y: 0.5 }, { x: 0.7, y: 0.6 });
  expect(await elementCount(page)).toBe(0);
  expect(await read(page, (s) => s.trail.laser.length)).toBeGreaterThan(0);
  await shot(page, "05-laser");
});

test("zoom controls and theme toggle work", async ({ page }) => {
  await page.getByTestId("zoom-in").click();
  expect(await read(page, (s) => s.zoomPercent)).toBe(120);
  await page.getByTestId("zoom-reset").click();
  expect(await read(page, (s) => s.zoomPercent)).toBe(100);

  await page.getByTestId("theme").click();
  expect(await read(page, (s) => s.theme)).toBe("dark");
  await shot(page, "06-dark");
});

test("exports an SVG download", async ({ page }) => {
  await selectTool(page, "ellipse");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.6, y: 0.6 });
  const downloadPromise = page.waitForEvent("download");
  await page.getByTestId("export-svg").click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe("drawing.svg");
});
