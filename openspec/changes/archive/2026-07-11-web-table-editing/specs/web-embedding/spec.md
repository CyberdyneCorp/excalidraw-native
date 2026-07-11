## ADDED Requirements

### Requirement: Table commands are gateable

`uiOptions.contextMenu` SHALL accept a `table` flag (default on) that shows or hides the context menu's table section, without affecting an embedder's ability to call the table APIs on the store.

#### Scenario: Embedder hides the table commands
- **WHEN** a client renders the editor with `contextMenu: { table: false }` and
  right-clicks a table cell
- **THEN** no table commands SHALL appear, while `store.insertTableRow(...)`
  SHALL still work
