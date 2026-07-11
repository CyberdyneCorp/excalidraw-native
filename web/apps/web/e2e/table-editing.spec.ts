import { expect, test } from "@playwright/test";
import { insertGenerator, ready, selectTool } from "./helpers.js";

/** Table row/column editing (web-table-editing): insert and delete rows and
 * columns from the context menu, with labels cleaned up and the gap closed. */

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

/** Cell (rectangle) and label (text) counts of the scene. */
const counts = (page) =>
  readStore(page, (s: never) => {
    const st = s as { scene: { visibleElements: { type: string }[] } };
    const els = st.scene.visibleElements;
    return {
      cells: els.filter((e) => e.type === "rectangle").length,
      labels: els.filter((e) => e.type === "text").length,
    };
  });

/** Right-click the table's top-left cell (in view coords). */
async function rightClickCell(page, row = 0, col = 0) {
  const at = await readStore(
    page,
    (s: never) => {
      const st = s as {
        scene: { visibleElements: { type: string; x: number; y: number; width: number; height: number }[] };
        viewport: { sceneToView(p: { x: number; y: number }): { x: number; y: number } };
      };
      const cells = st.scene.visibleElements
        .filter((e) => e.type === "rectangle")
        .sort((a, b) => a.y - b.y || a.x - b.x);
      const c = cells[0]!;
      return { x: c.x + c.width / 2, y: c.y + c.height / 2, w: c.width, h: c.height };
    },
  );
  const box = (await page.getByTestId("canvas").boundingBox())!;
  await page.mouse.click(box.x + at.x + at.w * col, box.y + at.y + at.h * row, {
    button: "right",
  });
}

test("insert a row and a column from the table context menu", async ({ page }) => {
  await insertGenerator(page, "table"); // 3×3 → 9 cells, 9 labels
  expect(await counts(page)).toEqual({ cells: 9, labels: 9 });

  await rightClickCell(page, 0, 0);
  await page.getByTestId("ctx-row-below").click();
  await expect.poll(async () => (await counts(page)).cells).toBe(12); // 4×3

  await rightClickCell(page, 0, 0);
  await page.getByTestId("ctx-col-right").click();
  await expect.poll(async () => (await counts(page)).cells).toBe(16); // 4×4
  expect((await counts(page)).labels).toBe(16); // every new cell has a label
});

test("delete a row and a column, leaving no orphan labels", async ({ page }) => {
  await insertGenerator(page, "table");

  await rightClickCell(page, 1, 0); // middle row
  await page.getByTestId("ctx-row-delete").click();
  await expect.poll(async () => (await counts(page)).cells).toBe(6); // 2×3
  expect((await counts(page)).labels).toBe(6); // labels went with the cells

  await rightClickCell(page, 0, 1);
  await page.getByTestId("ctx-col-delete").click();
  await expect.poll(async () => (await counts(page)).cells).toBe(4); // 2×2
  expect((await counts(page)).labels).toBe(4);

  // Undo restores the column with its labels.
  await page.keyboard.press("ControlOrMeta+z");
  await expect.poll(async () => (await counts(page)).cells).toBe(6);
  expect((await counts(page)).labels).toBe(6);
});

test("the table section only appears over a table cell", async ({ page }) => {
  // A plain rectangle: no table commands.
  await selectTool(page, "rectangle");
  const box = (await page.getByTestId("canvas").boundingBox())!;
  await page.mouse.move(box.x + box.width * 0.3, box.y + box.height * 0.3);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width * 0.45, box.y + box.height * 0.45, { steps: 4 });
  await page.mouse.up();

  await page.mouse.click(box.x + box.width * 0.3, box.y + box.height * 0.3, { button: "right" });
  await expect(page.getByTestId("ctx-row-above")).toHaveCount(0);
  await expect(page.getByTestId("ctx-wrap-frame")).toBeVisible(); // the rest is there
});

test("delete entries are disabled on a single-cell table", async ({ page }) => {
  await readStore(page, (s: never) => (s as { insertTable(r: number, c: number): void }).insertTable(1, 1));
  await page.waitForTimeout(100);

  await rightClickCell(page, 0, 0);
  await expect(page.getByTestId("ctx-row-delete")).toBeDisabled();
  await expect(page.getByTestId("ctx-col-delete")).toBeDisabled();
});

test("an embedder can hide the table commands (uiOptions.contextMenu.table)", async ({ page }) => {
  await page.goto("/embed.html?noTable=1");
  await ready(page);
  await readStore(page, (s: never) =>
    (s as { insertTable(r: number, c: number): void }).insertTable(3, 3),
  );
  await page.waitForTimeout(100);

  await rightClickCell(page, 0, 0);
  await expect(page.getByTestId("ctx-row-above")).toHaveCount(0); // hidden
  await expect(page.getByTestId("ctx-wrap-frame")).toBeVisible(); // rest of the menu intact

  // Hiding the chrome does not remove the capability.
  const grown = await page.evaluate(async () => {
    const st = (window as never as {
      __store: {
        scene: { visibleElements: { type: string; id: string }[] };
        insertTableRow(id: string, w: "above" | "below"): void;
      };
    }).__store;
    const cell = st.scene.visibleElements.find((e) => e.type === "rectangle")!;
    st.insertTableRow(cell.id, "below");
    return st.scene.visibleElements.filter((e) => e.type === "rectangle").length;
  });
  expect(grown).toBe(12);
});
