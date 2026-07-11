## 1. Core (controller)

- [x] 1.1 `tableGrid(group)` → sorted distinct column `x`s and row `y`s; `cellIndex(id)` → `{ group, row, col }`
- [x] 1.2 `insertTableRow(cellId, "above" | "below")` — shift following rows down (cells + labels), add one cell per column with an empty bound label; one undo step
- [x] 1.3 `insertTableColumn(cellId, "left" | "right")` — same, per row
- [x] 1.4 `deleteTableRow(cellId)` / `deleteTableColumn(cellId)` — remove cells *and* their bound labels, shift the rest back to close the gap; refuse the last row/column
- [x] 1.5 Unit tests: insert above/below/left/right (counts, positions, labels), delete (no orphan labels, gap closed), last-row/column guard, single-undo for each

## 2. Store

- [x] 2.1 `selectedTableCell` / `tableCellAt(id)` helper, and passthroughs: `insertTableRow(id, where)`, `insertTableColumn(id, where)`, `deleteTableRow(id)`, `deleteTableColumn(id)`, plus `canDeleteTableRow/Column(id)` guards
- [x] 2.2 Unit tests for the passthroughs (selection preserved / table reselected)

## 3. UI

- [x] 3.1 Context-menu table section (insert row above/below, insert column left/right, delete row, delete column) shown only over a table cell, delete entries disabled at one row/column
- [x] 3.2 `UIOptions.contextMenu.table` flag (default on) gating the section

## 4. Verification

- [x] 4.1 E2E: insert a row below and a column right from the menu; the table grows correctly
- [x] 4.2 E2E: delete a row and a column; cell + label counts drop, no orphan text, gap closed
- [x] 4.3 E2E: the table section is absent over a plain shape, and hidden when `contextMenu: { table: false }`

## 5. Docs & spec sync

- [x] 5.1 README: table editing note (+ the `uiOptions.contextMenu.table` flag)
- [x] 5.2 `openspec validate` clean; archive after merge
