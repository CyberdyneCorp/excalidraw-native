import { expect, test } from "@playwright/test";
import { drag, elementCount, ready, selectTool } from "./helpers.js";

/** Smart canvas (web-smart-canvas): flowchart quick-create, shape recognition,
 * canvas helpers, zen mode, command palette. */

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

const elements = (page) =>
  readStore(page, (s: never) => {
    const st = s as {
      scene: {
        visibleElements: {
          type: string;
          x: number;
          y: number;
          startBinding?: unknown;
          endBinding?: unknown;
        }[];
      };
    };
    return st.scene.visibleElements;
  });

test("Cmd/Ctrl+arrow spawns a connected flowchart node", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.3, y: 0.4 }, { x: 0.42, y: 0.55 }); // stays selected

  await page.keyboard.press("ControlOrMeta+ArrowRight");
  await expect.poll(async () => await elementCount(page)).toBe(3); // 2 shapes + arrow

  const all = await elements(page);
  const rects = all.filter((e) => e.type === "rectangle");
  const arrow = all.find((e) => e.type === "arrow")!;
  expect(rects).toHaveLength(2);
  expect(rects[1]!.x).toBeGreaterThan(rects[0]!.x); // spawned to the right
  expect(arrow.startBinding).not.toBeNull();
  expect(arrow.endBinding).not.toBeNull();
});

test("quick-arrow buttons spawn a connected node downward", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.35, y: 0.3 }, { x: 0.47, y: 0.42 });

  await expect(page.getByTestId("quick-down")).toBeVisible();
  await page.getByTestId("quick-down").click();

  await expect.poll(async () => await elementCount(page)).toBe(3);
  const rects = (await elements(page)).filter((e) => e.type === "rectangle");
  expect(rects[1]!.y).toBeGreaterThan(rects[0]!.y); // spawned below
});

test("snap to shape converts a rough sketch into a rectangle", async ({ page }) => {
  await selectTool(page, "freedraw");
  const box = (await page.getByTestId("canvas").boundingBox())!;
  const P = (fx: number, fy: number) => ({
    x: box.x + box.width * fx,
    y: box.y + box.height * fy,
  });
  // Trace a rough closed rectangle.
  const path = [
    P(0.3, 0.3),
    P(0.45, 0.31),
    P(0.6, 0.3),
    P(0.61, 0.45),
    P(0.6, 0.6),
    P(0.45, 0.61),
    P(0.3, 0.6),
    P(0.29, 0.45),
    P(0.3, 0.31),
  ];
  await page.mouse.move(path[0]!.x, path[0]!.y);
  await page.mouse.down();
  for (const p of path.slice(1)) await page.mouse.move(p.x, p.y, { steps: 3 });
  await page.mouse.up();

  await page.mouse.click(P(0.3, 0.3).x, P(0.3, 0.3).y, { button: "right" });
  await page.getByTestId("ctx-snap-shape").click();

  await expect
    .poll(async () => (await elements(page)).some((e) => e.type === "rectangle"))
    .toBe(true);
  expect((await elements(page)).some((e) => e.type === "freedraw")).toBe(false);
});

test("the scroll-back pill appears off-screen and recentres the view", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.45, y: 0.45 });
  await expect(page.getByTestId("scroll-back")).toHaveCount(0);

  // Pan far away with the hand tool until the content is off-screen.
  await selectTool(page, "hand");
  for (let i = 0; i < 4; i++) {
    await drag(page, { x: 0.2, y: 0.2 }, { x: 0.9, y: 0.9 });
  }
  await expect(page.getByTestId("scroll-back")).toBeVisible();

  await page.getByTestId("scroll-back").click();
  await expect(page.getByTestId("scroll-back")).toHaveCount(0); // content is back
});

test("grid, snap, and zoom-to-fit toggles work", async ({ page }) => {
  await page.getByTestId("toggle-grid").click();
  expect(await readStore(page, (s: never) => (s as { gridEnabled: boolean }).gridEnabled)).toBe(
    true,
  );
  await page.getByTestId("toggle-snap").click();
  expect(await readStore(page, (s: never) => (s as { snapEnabled: boolean }).snapEnabled)).toBe(
    true,
  );

  await selectTool(page, "rectangle");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.4, y: 0.4 });
  await page.getByTestId("zoom-in").click();
  await page.getByTestId("zoom-fit").click();
  // Zoom-to-fit leaves the content on screen.
  expect(
    await readStore(page, (s: never) => (s as { contentOffscreen: boolean }).contentOffscreen),
  ).toBe(false);
});

test("zen mode hides the chrome and Alt+Z restores it", async ({ page }) => {
  await expect(page.getByTestId("app-menu")).toBeVisible();
  await page.keyboard.press("Alt+z");
  await expect(page.getByTestId("app-menu")).toHaveCount(0);
  await expect(page.getByTestId("tool-rectangle")).toHaveCount(0);

  // Tools still work from the keyboard while in zen mode.
  await page.keyboard.press("2");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.45, y: 0.45 });
  expect(await elementCount(page)).toBe(1);

  await page.keyboard.press("Alt+z");
  await expect(page.getByTestId("app-menu")).toBeVisible();
});

test("the grid renders only when enabled", async ({ page }) => {
  // Sample the empty canvas: with the grid on, faint grid ink appears.
  const inkPixels = () =>
    page.evaluate(() => {
      const canvas = document.querySelector('[data-testid="canvas"]') as HTMLCanvasElement;
      const ctx = canvas.getContext("2d")!;
      const { data } = ctx.getImageData(0, 0, canvas.width, Math.min(200, canvas.height));
      let painted = 0;
      for (let i = 0; i < data.length; i += 4) {
        if (data[i]! < 250 || data[i + 1]! < 250 || data[i + 2]! < 250) painted++;
      }
      return painted;
    });
  const plain = await inkPixels();
  await page.getByTestId("toggle-grid").click();
  await page.waitForTimeout(150); // the 40ms revision poll repaints
  const gridded = await inkPixels();
  expect(gridded).toBeGreaterThan(plain);
});

test("the command palette filters and runs commands", async ({ page }) => {
  await page.keyboard.press("ControlOrMeta+k");
  await expect(page.getByTestId("command-palette")).toBeVisible();

  await page.getByTestId("palette-input").fill("rect");
  await expect(page.getByTestId("palette-item-tool-rectangle")).toBeVisible();
  await page.keyboard.press("Enter");

  await expect(page.getByTestId("command-palette")).toHaveCount(0);
  expect(await readStore(page, (s: never) => (s as { activeTool: string }).activeTool)).toBe(
    "rectangle",
  );

  // Escape closes it without running anything.
  await page.keyboard.press("ControlOrMeta+k");
  await expect(page.getByTestId("command-palette")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.getByTestId("command-palette")).toHaveCount(0);
});
