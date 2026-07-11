## ADDED Requirements

### Requirement: Insert a table row or column relative to a cell

The editor SHALL insert a row above or below, and a column to the left or right of, a given table cell: the following rows SHALL shift down (or columns right) by the cell size, and the new cells SHALL take the table's cell dimensions and style and each receive their own empty bound label. Insertion SHALL be a single undoable step and SHALL leave the table's grouping and `customData.table` marker intact.

#### Scenario: Insert a row above the clicked cell
- **WHEN** a 3×3 table's middle-row cell is targeted and a row is inserted above it
- **THEN** the table SHALL have 4 rows (12 cells), the rows below the insertion
  SHALL have shifted down by one cell height, the new row SHALL span every
  column, and a single undo SHALL restore the 3×3 table

#### Scenario: Insert a column to the right
- **WHEN** a column is inserted to the right of a cell
- **THEN** every row SHALL gain one cell at that position, the columns to its
  right SHALL shift right, and the new cells SHALL carry empty labels

### Requirement: Delete a table row or column

The editor SHALL delete the row or column containing a given cell — removing those cells **and their bound text labels** — and SHALL reflow the remaining rows (or columns) to close the gap, as one undoable step. Deleting the last remaining row or column SHALL be refused, leaving the table unchanged (a table always keeps at least one cell).

#### Scenario: Delete a row and close the gap
- **WHEN** the middle row of a 3×3 table is deleted
- **THEN** 3 cells and their 3 bound labels SHALL be removed, the rows below
  SHALL move up to close the gap, no orphaned text element SHALL remain, and a
  single undo SHALL restore the row with its labels

#### Scenario: The last row cannot be deleted
- **WHEN** a table has one row remaining and a row deletion is requested
- **THEN** the table SHALL be unchanged
