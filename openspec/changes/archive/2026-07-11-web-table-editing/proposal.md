# Table Row & Column Editing

## Why

Tables can be inserted (generators) and grown, but only crudely: the editor
has `addTableRow` / `addTableColumn`, which **append** a row/column at the
end, exposed as "+ Row" / "+ Col" buttons in the style panel. There is:

- **no way to delete** a row or column at all (no code exists),
- **no way to insert relative to a cell** (above/below/left/right), and
- **nothing in the right-click menu** for tables — the natural place to look.

So a table with a mistake in the middle can only be fixed by deleting the
whole table and rebuilding it.

## What Changes

- **Insert relative to the clicked cell** — insert a row above/below, or a
  column left/right of the cell under the cursor, shifting the following
  rows/columns down/right; new cells inherit the table's cell size and style
  and get their own (empty) bound label.
- **Delete the clicked cell's row or column** — removing its cells *and their
  bound labels*, then reflowing the remaining rows/columns to close the gap.
  Deleting the last remaining row or column SHALL be refused (a table always
  keeps at least one cell).
- **Table section in the context menu** — right-clicking a table cell offers
  Insert row above / Insert row below / Insert column left / Insert column
  right / Delete row / Delete column, gated on being over a table.
- The existing "+ Row" / "+ Col" panel buttons keep working (append).
- Store: `selectedTableCell` (group + row/column index of the current cell)
  and the insert/delete passthroughs; `uiOptions.contextMenu.table` gates the
  new section for embedders.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `generators`: ADDED requirements — table row/column insertion relative to a
  cell, and row/column deletion with label cleanup and reflow.
- `web-client`: the context menu grows a table section when the right-clicked
  element is a table cell.
- `web-embedding`: `uiOptions.contextMenu` gains a `table` flag.

## Impact

- `web/packages/excalidraw-svelte`: `EditorController` insert/delete row and
  column (+ cell indexing helpers); `EditorStore` passthroughs and
  `selectedTableCell`; unit tests.
- `web/packages/excalidraw-svelte/src/ui`: context-menu table section
  (`Excalidraw.svelte`), `UIOptions.contextMenu.table`.
- E2E: insert/delete via the context menu; label cleanup; last-row/column
  guard.
- No schema, file-format, or protocol changes — tables are ordinary grouped
  rectangles with bound text and a `customData.table` marker, exactly as
  today; iOS/Android untouched.
