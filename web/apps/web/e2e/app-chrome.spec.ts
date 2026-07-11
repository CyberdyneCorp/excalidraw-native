import { expect, test } from "@playwright/test";
import { drag, elementCount, ready, selectTool } from "./helpers.js";

/** App chrome & flows (web-app-chrome): tool lock, menu file flows, export
 * dialog + PNG scene-embed round-trip, welcome screen, help overlay. */

test.beforeEach(async ({ page }) => {
  await page.goto("/");
  await ready(page);
});

function readStore<T>(page, fn: (s: never) => T): Promise<T> {
  return page.evaluate(
    ([f]) => new Function("s", `return (${f})(s)`)((window as never as { __store: never }).__store),
    [fn.toString()] as const,
  );
}

test("tool lock keeps the drawing tool active", async ({ page }) => {
  await page.getByTestId("tool-lock").click();
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.2, y: 0.3 }, { x: 0.35, y: 0.45 });
  // Still the rectangle tool: draw a second one without re-picking.
  await drag(page, { x: 0.5, y: 0.3 }, { x: 0.65, y: 0.45 });
  expect(await elementCount(page)).toBe(2);
  expect(await readStore(page, (s: never) => (s as { activeTool: string }).activeTool)).toBe(
    "rectangle",
  );

  // Unlocking restores revert-to-selection.
  await page.getByTestId("tool-lock").click();
  await selectTool(page, "ellipse");
  await drag(page, { x: 0.2, y: 0.6 }, { x: 0.35, y: 0.75 });
  expect(await readStore(page, (s: never) => (s as { activeTool: string }).activeTool)).toBe(
    "selection",
  );
});

test("menu saves a document and resets the canvas undoably", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.5, y: 0.5 });

  // Save triggers a .excalidraw download.
  await page.getByTestId("app-menu").click();
  const savePromise = page.waitForEvent("download");
  await page.getByTestId("menu-save").click();
  const save = await savePromise;
  expect(save.suggestedFilename()).toBe("drawing.excalidraw");

  // Reset clears the scene; undo brings it back.
  await page.getByTestId("app-menu").click();
  await page.getByTestId("menu-reset").click();
  expect(await elementCount(page)).toBe(0);
  await page.keyboard.press("ControlOrMeta+z");
  expect(await elementCount(page)).toBe(1);
});

test("Open restores a saved .excalidraw document", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.5, y: 0.5 });
  await selectTool(page, "ellipse");
  await drag(page, { x: 0.6, y: 0.3 }, { x: 0.75, y: 0.5 });
  const json = await readStore(page, (s: never) => (s as { documentJSON(): string }).documentJSON());

  await page.getByTestId("app-menu").click();
  await page.getByTestId("menu-reset").click();
  expect(await elementCount(page)).toBe(0);

  // Feed the saved document back through the menu's file input.
  await page.setInputFiles('input[type="file"][accept*=".excalidraw"]', {
    name: "drawing.excalidraw",
    mimeType: "application/json",
    buffer: Buffer.from(json),
  });
  await expect
    .poll(async () => await elementCount(page))
    .toBe(2);
});

test("opening a PNG without an embedded scene is rejected", async ({ page }) => {
  // A 1x1 PNG with no scene chunk.
  const png = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
    "base64",
  );
  await page.setInputFiles('input[type="file"][accept*=".excalidraw"]', {
    name: "plain.png",
    mimeType: "image/png",
    buffer: png,
  });
  await expect(page.getByTestId("open-error")).toBeVisible();
  expect(await elementCount(page)).toBe(0); // scene untouched
});

test("export dialog downloads a PNG whose embedded scene reopens", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.5, y: 0.5 });
  await selectTool(page, "ellipse");
  await drag(page, { x: 0.6, y: 0.3 }, { x: 0.75, y: 0.5 });

  await page.getByTestId("app-menu").click();
  await page.getByTestId("menu-export").click();
  await expect(page.getByTestId("export-dialog")).toBeVisible();
  await page.getByTestId("export-scale-2").click();
  const pngPromise = page.waitForEvent("download");
  await page.getByTestId("export-run").click();
  const png = await pngPromise;
  expect(png.suggestedFilename()).toBe("drawing.png");

  // Byte-level round-trip: the exported PNG carries the scene and reopens.
  const restored = await page.evaluate(async () => {
    const w = window as never as {
      __store: {
        scene: { visibleElements: unknown[] };
        resetScene(): void;
        openPngScene(b: Uint8Array): boolean;
      };
      __exportPng(): Promise<Uint8Array | null>;
    };
    const bytes = await w.__exportPng();
    if (bytes === null) return { ok: false, count: -1 };
    w.__store.resetScene();
    const ok = w.__store.openPngScene(bytes);
    return { ok, count: w.__store.scene.visibleElements.length };
  });
  expect(restored.ok).toBe(true);
  expect(restored.count).toBe(2);
});

test("transparent selection-only export renders just the selection", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.45, y: 0.45 });
  await selectTool(page, "ellipse");
  await drag(page, { x: 0.6, y: 0.3 }, { x: 0.75, y: 0.45 }); // stays selected

  const sizes = await page.evaluate(async () => {
    const w = window as never as {
      __exportPngWith(o: {
        scale: 1 | 2 | 3;
        background: boolean;
        selectionOnly: boolean;
        embed: boolean;
      }): Promise<Uint8Array | null>;
    };
    const all = await w.__exportPngWith({
      scale: 1,
      background: true,
      selectionOnly: false,
      embed: false,
    });
    const sel = await w.__exportPngWith({
      scale: 1,
      background: false,
      selectionOnly: true,
      embed: false,
    });
    return { all: all?.length ?? 0, sel: sel?.length ?? 0 };
  });
  // Both produced bytes, and the selection-only export is a smaller image.
  expect(sizes.all).toBeGreaterThan(0);
  expect(sizes.sel).toBeGreaterThan(0);
  expect(sizes.sel).toBeLessThan(sizes.all);
});

test("welcome screen shows on an empty canvas and clears once drawing starts", async ({ page }) => {
  await expect(page.getByTestId("welcome")).toBeVisible();
  await selectTool(page, "rectangle");
  await expect(page.getByTestId("welcome")).toHaveCount(0);
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.5, y: 0.5 });
  await selectTool(page, "selection");
  await expect(page.getByTestId("welcome")).toHaveCount(0); // scene is not empty
});

test("help overlay opens with ? and closes with Escape", async ({ page }) => {
  await page.keyboard.press("?");
  const help = page.getByTestId("help-overlay");
  await expect(help).toBeVisible();
  await expect(help).toContainText("Rectangle");
  await expect(help).toContainText("Selection");
  await page.keyboard.press("Escape");
  await expect(help).toHaveCount(0);
  expect(await elementCount(page)).toBe(0); // scene untouched
});
