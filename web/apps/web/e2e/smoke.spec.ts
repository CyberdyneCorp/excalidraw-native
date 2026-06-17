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

test("the Mermaid diagram is grouped, labelled, and moves as one unit", async ({ page }) => {
  await page.getByTestId("gen-mermaid").click();
  await page.waitForTimeout(120);
  // Nodes (rect/diamond) + bound labels + connecting arrows.
  const shape = await read(page, (s) => ({
    nodes: s.scene.visibleElements.filter((e) => e.type === "rectangle" || e.type === "diamond").length,
    arrows: s.scene.visibleElements.filter((e) => e.type === "arrow").length,
    labels: s.scene.visibleElements.filter((e) => e.type === "text" && e.containerId !== null).length,
  }));
  expect(shape.nodes).toBeGreaterThanOrEqual(3);
  expect(shape.arrows).toBeGreaterThanOrEqual(2);
  expect(shape.labels).toBe(shape.nodes);
  await shot(page, "09-mermaid");

  // Select the whole diagram and drag it; every element shifts by the same delta.
  await selectTool(page, "selection");
  const cb = (await page.getByTestId("canvas").boundingBox())!;
  const node = await read(page, (s) => {
    const r = s.scene.visibleElements.find((e) => e.type === "rectangle")!;
    return { id: r.id, cx: r.x + r.width / 2, cy: r.y + r.height / 2, x0: r.x, y0: r.y };
  });
  await page.mouse.move(cb.x + node.cx, cb.y + node.cy);
  await page.mouse.down();
  await page.mouse.move(cb.x + node.cx + 100, cb.y + node.cy - 60, { steps: 8 });
  await page.mouse.up();
  const after = await read(page, (s) => {
    const r = s.scene.visibleElements.find((e) => e.type === "rectangle")!;
    return { x: r.x, y: r.y, arrows: s.scene.visibleElements.filter((e) => e.type === "arrow").length };
  });
  expect(after.x).toBeCloseTo(node.x0 + 100, 0);
  expect(after.y).toBeCloseTo(node.y0 - 60, 0);
  expect(after.arrows).toBe(shape.arrows); // arrows preserved, not orphaned
  await shot(page, "10-mermaid-moved");
});

test("tables gain rows and columns from the toolbar", async ({ page }) => {
  await page.getByTestId("gen-table").click();
  const cells = () =>
    read(page, (s) => s.scene.visibleElements.filter((e) => e.type === "rectangle").length);
  expect(await cells()).toBe(9); // default 3×3

  // The table is selected after insert; the row/col buttons appear for it.
  await expect(page.getByTestId("table-add-row")).toBeVisible();
  await page.getByTestId("table-add-row").click();
  expect(await cells()).toBe(12); // 4×3
  await page.getByTestId("table-add-col").click();
  expect(await cells()).toBe(16); // 4×4
  await page.waitForTimeout(120); // let the canvas poll repaint the new column
  await shot(page, "11-table-grown");
});

test("double-clicking a table cell opens an editor sized to the cell", async ({ page }) => {
  await page.getByTestId("gen-table").click();
  await selectTool(page, "selection");
  const cb = (await page.getByTestId("canvas").boundingBox())!;
  const cell = await read(page, (s) => {
    const c = s.scene.visibleElements.find((e) => e.type === "rectangle")!;
    return { x: c.x + c.width / 2, y: c.y + c.height / 2, w: c.width };
  });
  await page.mouse.dblclick(cb.x + cell.x, cb.y + cell.y);
  const editor = page.getByTestId("text-editor");
  await expect(editor).toBeVisible();
  const box = (await editor.boundingBox())!;
  // The editor matches the cell width (~120), not the old 222px overflow.
  expect(box.width).toBeGreaterThan(cell.w - 10);
  expect(box.width).toBeLessThan(cell.w + 10);
  await editor.fill("1");
  await editor.press("Enter");
  await shot(page, "12-cell-edit");
});

test("double-clicking a chart changes its plot type and data", async ({ page }) => {
  await page.getByTestId("gen-chart").click(); // bar chart of [10,20,15,30] → 4 bars
  const bars = () =>
    read(page, (s) => s.scene.visibleElements.filter((e) => e.type === "rectangle").length);
  expect(await bars()).toBe(4);

  await selectTool(page, "selection");
  const cb = (await page.getByTestId("canvas").boundingBox())!;
  const bar = await read(page, (s) => {
    const r = s.scene.visibleElements.find((e) => e.type === "rectangle")!;
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  await page.mouse.dblclick(cb.x + bar.x, cb.y + bar.y);
  await expect(page.getByTestId("chart-editor")).toBeVisible();

  await page.getByTestId("chart-kind").selectOption("line");
  await page.getByTestId("chart-data").fill("5, 9, 4, 12, 7");
  await page.getByTestId("chart-apply").click();
  await page.waitForTimeout(120);

  // A line chart has no bars; the data became 5 points.
  expect(await bars()).toBe(0);
  expect(await read(page, (s) => s.scene.visibleElements.some((e) => e.type === "line"))).toBe(true);
  await shot(page, "13-chart-edited");
});

test("moving a sticky note carries its label and keeps a tight selection", async ({ page }) => {
  await page.getByTestId("gen-note").click();
  const editor = page.getByTestId("text-editor");
  await editor.fill("Leo");
  await editor.press("Enter");
  await selectTool(page, "selection");

  const cb = (await page.getByTestId("canvas").boundingBox())!;
  const c = await read(page, (s) => {
    const n = s.scene.visibleElements.find((e) => e.type === "rectangle")!;
    return { x: n.x + n.width / 2, y: n.y + n.height / 2 };
  });
  // Drag the note up-left; the bound text must move with it (not strand).
  await page.mouse.move(cb.x + c.x, cb.y + c.y);
  await page.mouse.down();
  await page.mouse.move(cb.x + c.x - 250, cb.y + c.y - 120, { steps: 8 });
  await page.mouse.up();

  // Re-select the moved note: its group bounds stay tight (160×160), not ballooned.
  const c2 = await read(page, (s) => {
    const n = s.scene.visibleElements.find((e) => e.type === "rectangle")!;
    return { x: n.x + n.width / 2, y: n.y + n.height / 2 };
  });
  await page.mouse.move(cb.x + c2.x, cb.y + c2.y);
  await page.mouse.down();
  await page.mouse.up();
  const bounds = await read(page, (s) => s.controller.selectionBounds);
  expect(bounds!.maxX - bounds!.minX).toBeCloseTo(160, 0);
  expect(bounds!.maxY - bounds!.minY).toBeCloseTo(160, 0);
  await shot(page, "07-note-moved");
});

test("double-clicking a line enters point (spline) editing and drags a vertex", async ({ page }) => {
  await selectTool(page, "line");
  await drag(page, { x: 0.2, y: 0.6 }, { x: 0.5, y: 0.72 });
  expect(await read(page, (s) => s.isLinearEditing)).toBe(false);

  await selectTool(page, "selection");
  const cb = (await page.getByTestId("canvas").boundingBox())!;
  // The end vertex in scene coords (== view coords at the default viewport).
  const end = await read(page, (s) => {
    const l = s.scene.visibleElements.find((e) => e.type === "line") as
      | { x: number; y: number; points: [number, number][] }
      | undefined;
    const last = l!.points[l!.points.length - 1]!;
    return { x: l!.x + last[0], y: l!.y + last[1] };
  });
  // Double-click the line to enter point editing.
  await page.mouse.dblclick(cb.x + end.x, cb.y + end.y);
  expect(await read(page, (s) => s.isLinearEditing)).toBe(true);
  await page.waitForTimeout(120); // let the canvas poll repaint into point-edit mode
  await shot(page, "08-line-edit");

  // Drag the end vertex 80px down; the line's last point must change.
  await page.mouse.move(cb.x + end.x, cb.y + end.y);
  await page.mouse.down();
  await page.mouse.move(cb.x + end.x, cb.y + end.y + 80, { steps: 6 });
  await page.mouse.up();
  const moved = await read(page, (s) => {
    const l = s.scene.visibleElements.find((e) => e.type === "line") as { height: number };
    return l.height;
  });
  // The line got taller after pulling the vertex down.
  expect(moved).toBeGreaterThan(70);
});

test("the fill-pattern selector changes a shape's fill style", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.6, y: 0.6 });
  // Box-select the rectangle, then switch its fill pattern.
  await selectTool(page, "selection");
  await drag(page, { x: 0.2, y: 0.2 }, { x: 0.7, y: 0.7 });
  await page.getByTestId("fill-style").selectOption("cross-hatch");
  expect(
    await read(page, (s) =>
      s.scene.visibleElements.some((e) => e.type === "rectangle" && e.fillStyle === "cross-hatch"),
    ),
  ).toBe(true);
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
