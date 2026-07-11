## ADDED Requirements

### Requirement: Table commands in the context menu

Right-clicking a table cell SHALL offer a table section in the context menu: Insert row above, Insert row below, Insert column left, Insert column right, Delete row, and Delete column — each acting on the right-clicked cell. The section SHALL appear only when the right-clicked element belongs to a table, and the delete entries SHALL be disabled when only one row (or column) remains.

#### Scenario: Insert and delete a row from the menu
- **WHEN** the user right-clicks a cell of a 3×3 table and chooses "Insert row
  below", then right-clicks again and chooses "Delete row"
- **THEN** the table SHALL grow to 4 rows and then return to 3, with no orphan
  labels left behind

#### Scenario: The table section is table-only
- **WHEN** the user right-clicks a plain rectangle
- **THEN** no table commands SHALL be offered
