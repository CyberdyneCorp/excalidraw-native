# Design — Table Row & Column Editing

## Context

Tables are ordinary grouped rectangles: each cell carries
`customData.table = <groupID>`, a `groupIds` entry, and a bound text label
(`boundElements` → text with `containerId`). `createTable` lays cells out on a
uniform grid (120×44 by default); `addTableRow`/`addTableColumn` append at the
bottom/right by reusing `addTableCell`. There is no delete path and no
cell-relative insert, and nothing table-related in the context menu.

## Goals / Non-Goals

**Goals:** insert a row/column relative to a cell (above/below/left/right);
delete the row/column containing a cell, removing bound labels and closing the
gap; table commands in the context menu, gateable via `uiOptions`.

**Non-Goals:** resizing individual rows/columns; merging cells; header styling;
per-cell borders; sorting. (Tables remain a light generator, not a spreadsheet.)

## Decisions

**D1 — Index rows/columns by coordinate, not by stored indices.** Cells have no
row/col fields; the grid is implied by geometry. `tableGrid(group)` derives the
sorted distinct `x`s (columns) and `y`s (rows) from the cells, so a cell's
index is the position of its `x`/`y` in those arrays. This keeps the model
unchanged (no new fields → no file-format or protocol impact) and matches how
`addTableRow`/`addTableColumn` already work.

**D2 — Insert = shift + add, in one transaction.** Rows at or after the
insertion point shift down by the cell height (their bound labels shift with
them, since labels are re-centred from the container by the renderer *and* by
`setText`, but the stored label `y` must move too — so labels are shifted
explicitly). Then a new cell (with its own empty label) is added per column.

**D3 — Delete = remove cells + their labels, then shift back.** The labels are
found via each cell's `boundElements`, so no orphan text can survive
(regression risk called out in the spec). Rows after the deleted one shift up
by the cell height. Refuse when only one row/column remains.

**D4 — Cell size comes from the target cell**, not a constant, so tables whose
cells were resized still insert consistently.

**D5 — The context menu acts on the right-clicked cell**, not merely on the
selection: `openMenu` already resolves the hit element, so the menu passes that
id to the table commands. A table cell is hit-tested like any rectangle.

## Risks / Trade-offs

- [Coordinate indexing is float-sensitive] → distinct coordinates are collected
  with a small epsilon-free `Set` on exact values, which is safe because cells
  are laid out and shifted by exact multiples of the same cell size; a resize
  of individual cells is a non-goal.
- [Deleting cells could strand labels] → labels are deleted through the cell's
  `boundElements`, and a unit test asserts zero orphan text elements remain.

## Migration Plan

No data, file-format, or protocol changes; one PR. Existing tables keep working
(the new operations are derived from geometry).

## Open Questions

None.
