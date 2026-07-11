import { expect, test } from "@playwright/test";
import { drag, elementCount, ready } from "./helpers.js";

/** The public embedding API (web-embeddable-editor): a client mounts
 * <Excalidraw> with uiOptions, viewMode, theming, slots, and callbacks.
 * Driven through `embed.html`, which consumes the package exactly as a
 * third-party would. */

function readStore<T>(page, fn: (s: never) => T): Promise<T> {
  return page.evaluate(
    ([f]) => new Function("s", `return (${f})(s)`)((window as never as { __store: never }).__store),
    [fn.toString()] as const,
  );
}

test("a client renders the full editor with one component", async ({ page }) => {
  await page.goto("/embed.html");
  await ready(page);
  // The default component is the complete editor.
  await expect(page.getByTestId("tool-rectangle")).toBeVisible();
  await expect(page.getByTestId("app-menu")).toBeVisible();
});

test("uiOptions hides chrome and narrows the toolbar, drawing still works", async ({ page }) => {
  await page.goto("/embed.html?minimal=1");
  await ready(page);

  // Only the three configured tools appear.
  await expect(page.getByTestId("tool-selection")).toBeVisible();
  await expect(page.getByTestId("tool-rectangle")).toBeVisible();
  await expect(page.getByTestId("tool-arrow")).toBeVisible();
  await expect(page.getByTestId("tool-ellipse")).toHaveCount(0);
  await expect(page.getByTestId("tool-lock")).toHaveCount(0);
  await expect(page.getByTestId("more-tools")).toHaveCount(0);

  // The hidden chrome is absent…
  await expect(page.getByTestId("app-menu")).toHaveCount(0);
  await expect(page.getByTestId("panel-toggle")).toHaveCount(0);

  // …but the editor still works.
  await page.getByTestId("tool-rectangle").click();
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.5, y: 0.5 });
  expect(await elementCount(page)).toBe(1);

  // Hiding chrome does not remove capability: the store can still export.
  const svg = await readStore(page, (s: never) => (s as { exportSvg(): string }).exportSvg());
  expect(svg).toContain("<svg");
});

test("viewMode blocks edits but keeps pan and zoom", async ({ page }) => {
  await page.goto("/embed.html?viewMode=1");
  await ready(page);

  // Drawing tools are gone and pointer drags create nothing.
  await expect(page.getByTestId("tool-rectangle")).toBeVisible(); // toolbar visible…
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.5, y: 0.5 });
  expect(await elementCount(page)).toBe(0); // …but edits are swallowed

  // Panning still works (middle-drag) and zooming still works.
  const box = (await page.getByTestId("canvas").boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down({ button: "middle" });
  await page.mouse.move(box.x + box.width / 2 + 120, box.y + box.height / 2 + 80, { steps: 5 });
  await page.mouse.up({ button: "middle" });
  expect(
    await readStore(page, (s: never) => (s as { viewport: { scrollX: number } }).viewport.scrollX),
  ).toBeGreaterThan(50);
});

test("onReady and onChange fire for the host", async ({ page }) => {
  await page.goto("/embed.html");
  await ready(page); // ready() waits for __store, which onReady sets

  await page.getByTestId("tool-rectangle").click();
  await drag(page, { x: 0.3, y: 0.3 }, { x: 0.5, y: 0.5 });

  // onChange fires as the host edits.
  await expect
    .poll(async () => await page.evaluate(() => (window as never as { __changes?: number }).__changes ?? 0))
    .toBeGreaterThan(0);
});

test("a client can re-theme the chrome and the overlay", async ({ page }) => {
  await page.goto("/embed.html?themed=1");
  await ready(page);

  // The documented CSS tokens drive the chrome.
  const island = await page
    .getByTestId("tool-rectangle")
    .evaluate((el) => getComputedStyle(el.closest(".island")!).backgroundColor);
  expect(island).toBe("rgb(16, 35, 58)"); // the client's --excal-island

  // Overlay colours come from the prop: draw + select, then sample the
  // selection box ink for the client's red accent.
  await page.getByTestId("tool-rectangle").click();
  await drag(page, { x: 0.35, y: 0.35 }, { x: 0.55, y: 0.55 });
  await page.waitForTimeout(150);
  const hasRedOverlay = await page.evaluate(() => {
    const canvas = document.querySelector('[data-testid="canvas"]') as HTMLCanvasElement;
    const { data } = canvas.getContext("2d")!.getImageData(0, 0, canvas.width, canvas.height);
    for (let i = 0; i < data.length; i += 4) {
      if (data[i]! > 200 && data[i + 1]! < 80 && data[i + 2]! < 80) return true;
    }
    return false;
  });
  expect(hasRedOverlay).toBe(true);
});

test("a host slot renders alongside the built-in chrome", async ({ page }) => {
  await page.goto("/embed.html");
  await ready(page);
  await expect(page.getByTestId("host-button")).toBeVisible();
  await expect(page.getByTestId("app-menu")).toBeVisible(); // built-in chrome intact
});
