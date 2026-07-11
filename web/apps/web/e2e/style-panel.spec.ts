import { expect, test } from "@playwright/test";
import { drag, openPanel, ready, selectTool } from "./helpers.js";

/** Style-panel parity (web-style-panel-parity): swatches, segmented controls,
 * contextual text/arrow sections, selection reflection, and persistence. */

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

const firstElement = (page) =>
  readStore(page, (s: never) => {
    const st = s as {
      scene: {
        visibleElements: {
          type: string;
          strokeColor: string;
          strokeStyle: string;
          roughness: number;
          opacity: number;
          fontSize?: number;
          textAlign?: string;
          elbowed?: boolean;
          startArrowhead?: string | null;
          endArrowhead?: string | null;
          roundness?: { type: number } | null;
        }[];
      };
    };
    return st.scene.visibleElements[0] ?? null;
  });

test("styles a selected shape: dashed, cartoonist, 50% opacity", async ({ page }) => {
  await selectTool(page, "rectangle");
  await drag(page, { x: 0.35, y: 0.3 }, { x: 0.55, y: 0.5 }); // stays selected
  await openPanel(page);

  await page.getByTestId("stroke-style-dashed").click();
  await page.getByTestId("sloppiness-2").click();
  await page.getByTestId("opacity").fill("50");

  const el = await firstElement(page);
  expect(el?.strokeStyle).toBe("dashed");
  expect(el?.roughness).toBe(2);
  expect(el?.opacity).toBe(50);
});

test("swatch with empty selection styles the next element; panel reflects a selection", async ({
  page,
}) => {
  // Picking the red stroke swatch with a drawing tool active (no selection)
  // sets the default for the next element.
  await selectTool(page, "ellipse");
  await openPanel(page);
  await page.locator('[aria-label="Stroke #e03131"]').click();
  await drag(page, { x: 0.35, y: 0.3 }, { x: 0.5, y: 0.45 });
  const el = await firstElement(page);
  expect(el?.strokeColor).toBe("#e03131");

  // The drawn ellipse stays selected: the panel reflects its values.
  await page.getByTestId("stroke-style-dashed").click();
  await expect(page.getByTestId("stroke-style-dashed")).toHaveClass(/active/);
  await expect(page.locator('[aria-label="Stroke #e03131"]')).toHaveClass(/active/);
});

test("text section drives font size and alignment", async ({ page }) => {
  await selectTool(page, "text");
  await openPanel(page); // text tool context shows the font section
  await page.getByTestId("font-size-l").click();
  await page.getByTestId("text-align-center").click();

  const at = await page.getByTestId("canvas").boundingBox();
  await page.mouse.click(at!.x + at!.width * 0.4, at!.y + at!.height * 0.4);
  await page.keyboard.type("Hi");
  await page.keyboard.press("Enter");

  const el = await firstElement(page);
  expect(el?.fontSize).toBe(28);
  expect(el?.textAlign).toBe("center");
});

test("arrow section drives type and arrowheads, and fields persist to the document", async ({
  page,
}) => {
  await selectTool(page, "arrow");
  await drag(page, { x: 0.3, y: 0.4 }, { x: 0.6, y: 0.4 }); // stays selected
  await openPanel(page);

  await page.getByTestId("arrowhead-start").selectOption("triangle");
  await page.getByTestId("arrowhead-end").selectOption("none");
  await page.getByTestId("arrow-type-elbow").click();

  const el = await firstElement(page);
  expect(el?.startArrowhead).toBe("triangle");
  expect(el?.endArrowhead).toBeNull();
  expect(el?.elbowed).toBe(true);

  // Curved round-trips too, and everything persists in the saved document.
  await page.getByTestId("arrow-type-curved").click();
  const doc = await readStore(page, (s: never) => {
    const st = s as { documentJSON(): string };
    return JSON.parse(st.documentJSON()) as {
      elements: {
        type: string;
        startArrowhead?: string | null;
        elbowed?: boolean;
        roundness?: { type: number } | null;
      }[];
    };
  });
  const arrow = doc.elements.find((e) => e.type === "arrow");
  expect(arrow?.startArrowhead).toBe("triangle");
  expect(arrow?.elbowed).toBe(false);
  expect(arrow?.roundness?.type).toBe(2);
});
