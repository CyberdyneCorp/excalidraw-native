import { expect, test } from "@playwright/test";
import { drag, elementCount, ready, selectTool } from "./helpers.js";

/** Context menu & clipboard (web-context-menu-clipboard): cut/copy/paste,
 * copy/paste styles, wrap in frame, 4-step z-order, empty-canvas menu. */

test.beforeEach(async ({ page, context }) => {
  await context.grantPermissions(["clipboard-read", "clipboard-write"]);
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
          id: string;
          type: string;
          x: number;
          strokeColor: string;
          strokeStyle: string;
          frameId?: string | null;
        }[];
      };
    };
    return st.scene.visibleElements;
  });

async function rightClick(page, fx: number, fy: number) {
  const box = (await page.getByTestId("canvas").boundingBox())!;
  await page.mouse.click(box.x + box.width * fx, box.y + box.height * fy, { button: "right" });
}

test("copy and paste round-trips elements through the clipboard", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.45, y: 0.45 }); // stays selected

  await page.keyboard.press("ControlOrMeta+c");
  await page.mouse.move(600, 500); // paste lands at the cursor
  await page.keyboard.press("ControlOrMeta+v");

  await expect.poll(async () => await elementCount(page)).toBe(2);
  const all = await elements(page);
  expect(new Set(all.map((e) => e.id)).size).toBe(2); // distinct ids
});

test("cut removes the selection and undo restores it", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.45, y: 0.45 });

  await page.keyboard.press("ControlOrMeta+x");
  await expect.poll(async () => await elementCount(page)).toBe(0);
  await page.keyboard.press("ControlOrMeta+z");
  expect(await elementCount(page)).toBe(1);
});

test("pasting plain text creates a text element", async ({ page }) => {
  // Put text on the clipboard, then paste it onto the canvas.
  await page.evaluate(() => navigator.clipboard.writeText("hello from the clipboard"));
  const box = (await page.getByTestId("canvas").boundingBox())!;
  await page.mouse.move(box.x + box.width * 0.5, box.y + box.height * 0.5);
  await page.keyboard.press("ControlOrMeta+v");

  await expect.poll(async () => await elementCount(page)).toBe(1);
  const text = (await elements(page))[0]!;
  expect(text.type).toBe("text");
});

test("copy styles → paste styles transfers the style across shapes", async ({ page }) => {
  // A dashed red rectangle…
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.25, y: 0.3 }, { x: 0.4, y: 0.45 });
  await page.getByTestId("panel-toggle").click();
  await page.locator('[aria-label="Stroke #e03131"]').click();
  await page.getByTestId("stroke-style-dashed").click();
  await page.getByTestId("panel-collapse").click();

  await rightClick(page, 0.32, 0.37);
  await page.getByTestId("ctx-copy-styles").click();

  // …and a plain ellipse that takes its style.
  await selectTool(page, "ellipse");
  await drag(page, { x: 0.6, y: 0.3 }, { x: 0.75, y: 0.45 });
  await rightClick(page, 0.67, 0.37);
  await page.getByTestId("ctx-paste-styles").click();

  const ellipse = (await elements(page)).find((e) => e.type === "ellipse")!;
  expect(ellipse.strokeColor).toBe("#e03131");
  expect(ellipse.strokeStyle).toBe("dashed");
});

test("wrap selection in frame adopts the shapes", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.25, y: 0.3 }, { x: 0.4, y: 0.45 });
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.55, y: 0.3 }, { x: 0.7, y: 0.45 });
  await page.keyboard.press("ControlOrMeta+a");

  await rightClick(page, 0.32, 0.37);
  await page.getByTestId("ctx-wrap-frame").click();

  const all = await elements(page);
  const frame = all.find((e) => e.type === "frame")!;
  expect(frame).toBeDefined();
  const rects = all.filter((e) => e.type === "rectangle");
  expect(rects.every((r) => r.frameId === frame.id)).toBe(true);
});

test("the menu offers four z-order steps", async ({ page }) => {
  for (const x of [0.3, 0.35, 0.4]) {
    await selectTool(page, "rectangle");
    await drag(page, { x, y: 0.3 }, { x: x + 0.1, y: 0.45 });
  }
  // The last drawn (topmost) rectangle is selected; send it backward once.
  const topId = (await elements(page)).at(-1)!.id;
  await rightClick(page, 0.44, 0.37);
  await page.getByTestId("ctx-backward").click();
  let order = (await elements(page)).map((e) => e.id);
  expect(order.indexOf(topId)).toBe(1); // moved one step down from index 2

  await rightClick(page, 0.44, 0.37);
  await page.getByTestId("ctx-back").click();
  order = (await elements(page)).map((e) => e.id);
  expect(order.indexOf(topId)).toBe(0); // now at the bottom
});

test("right-clicking an element selects it and shows the element menu", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.45, y: 0.45 });
  await page.keyboard.press("Escape");
  // Deselect by clicking empty canvas, then right-click the shape itself.
  await selectTool(page, "selection");
  const box = (await page.getByTestId("canvas").boundingBox())!;
  await page.mouse.click(box.x + box.width * 0.8, box.y + box.height * 0.8);
  expect(await readStore(page, (s: never) => (s as { selectedCount: number }).selectedCount)).toBe(
    0,
  );

  await rightClick(page, 0.31, 0.31); // on the shape's edge
  await expect(page.getByTestId("ctx-copy-styles")).toBeVisible();
  expect(
    await readStore(page, (s: never) => (s as { selectedCount: number }).selectedCount),
  ).toBeGreaterThan(0);
});

test("the empty-canvas menu is the short one even with a selection", async ({ page }) => {
  // A selected shape must NOT turn an empty-canvas right-click into the
  // element menu (regression: the menu used to key on the selection count).
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.2, y: 0.2 }, { x: 0.35, y: 0.35 }); // stays selected
  await rightClick(page, 0.75, 0.75);
  await expect(page.getByTestId("ctx-zoomfit")).toBeVisible();
  await expect(page.getByTestId("ctx-copy-styles")).toHaveCount(0);
  await page.keyboard.press("Escape");
});

test("the empty-canvas menu is the short one", async ({ page }) => {
  await rightClick(page, 0.6, 0.7);
  await expect(page.getByTestId("ctx-paste")).toBeVisible();
  await expect(page.getByTestId("ctx-selectall")).toBeVisible();
  await expect(page.getByTestId("ctx-zoomfit")).toBeVisible();
  await expect(page.getByTestId("ctx-delete")).toHaveCount(0);
  await expect(page.getByTestId("ctx-copy-styles")).toHaveCount(0);
});
