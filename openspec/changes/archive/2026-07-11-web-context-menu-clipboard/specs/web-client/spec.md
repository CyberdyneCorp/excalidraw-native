## MODIFIED Requirements

### Requirement: Selection context menu

The web canvas SHALL open a context menu on right-click. Over a selection it SHALL offer: Cut, Copy, Paste, Copy to clipboard as PNG, Copy as SVG, Copy styles, Paste styles, Wrap selection in frame, Duplicate, Group, Ungroup, Send backward, Bring forward, Send to back, Bring to front, Flip horizontal, Flip vertical, Add link, Lock, Select all, and Delete. Over empty canvas it SHALL offer a shorter menu: Paste, Select all, and Zoom to fit. Selection-dependent items SHALL be disabled when not applicable — Group only with two or more selected elements, Ungroup only when the selection contains a grouped element, Paste styles only when styles have been copied, and the selection commands only with a non-empty selection. Choosing an item SHALL run the action and close the menu; clicking outside or pressing Escape SHALL dismiss it. (src: web/apps/web/src/App.svelte, web/packages/excalidraw-svelte/src/svelte/editor-store.ts)

#### Scenario: Group, ungroup, and delete via the menu
- GIVEN two selected elements
- WHEN the user right-clicks and chooses Group
- THEN the elements SHALL be grouped, the menu SHALL close, and a subsequent
  right-click SHALL offer an enabled Ungroup; choosing Delete SHALL remove the
  selection (src: web/apps/web/e2e/pan-zoom-contextmenu.spec.ts)

#### Scenario: Menu items gate on the selection
- GIVEN no selection
- WHEN the context menu is shown
- THEN the selection commands (Group, Ungroup, Duplicate, reorder, flip, lock,
  link, Delete) SHALL be disabled or absent while Select all and Paste remain
  available (src: web/apps/web/src/App.svelte)

#### Scenario: The empty-canvas menu is the short one
- WHEN the user right-clicks empty canvas with nothing selected
- THEN the menu SHALL offer Paste, Select all, and Zoom to fit, and SHALL NOT
  offer the element commands

#### Scenario: Four-step z-order
- GIVEN three stacked elements with the middle one selected
- WHEN the user chooses Bring forward, then Send to back
- THEN the element SHALL move one step up in the z-order, then to the bottom

## ADDED Requirements

### Requirement: Clipboard cut, copy, and paste

The client SHALL support Cut (⌘/Ctrl+X), Copy (⌘/Ctrl+C), and Paste (⌘/Ctrl+V) from the keyboard and the context menu, over the system clipboard. Copy and Cut SHALL write the selection as an `.excalidraw` payload (the existing file format, so the clipboard interoperates with excalidraw.com); Cut SHALL then delete the selection as one undoable step. Paste SHALL accept: an `.excalidraw` payload (elements re-id'd, offset, and selected), an **image file** (inserted as an image element), and **plain text** (inserted as a text element). Pasted content SHALL land at the last pointer position on the canvas. Clipboard shortcuts SHALL NOT fire while a text editor is open (the editor's own clipboard handling applies).

#### Scenario: Copy and paste round-trip
- **WHEN** the user selects two elements, copies, and pastes
- **THEN** two new elements SHALL be added (distinct ids), offset from the
  originals and left selected, with the originals unchanged

#### Scenario: Cut removes the selection in one undo step
- **WHEN** the user cuts a selected element and presses undo
- **THEN** the element SHALL be gone after the cut and restored by the undo

#### Scenario: Pasting external content
- **WHEN** the clipboard holds a PNG image, and separately plain text
- **THEN** pasting SHALL create an image element sized to the bitmap, and a
  text element carrying the text, respectively

### Requirement: Copy as image

The context menu SHALL offer "Copy to clipboard as PNG" and "Copy as SVG": the first SHALL write a PNG of the selection (or the whole scene when nothing is selected) to the clipboard as an image blob, the second SHALL write the SVG source as text. Both SHALL use canonical (light-theme) colours.

#### Scenario: PNG lands on the clipboard
- **WHEN** the user selects a shape and chooses "Copy to clipboard as PNG"
- **THEN** the clipboard SHALL hold a PNG image of that shape

### Requirement: Copy and paste styles

The context menu SHALL offer "Copy styles" (capturing the first selected element's style properties: stroke colour, background, fill style, stroke width, stroke style, roughness, roundness, opacity, font family/size/alignment, and arrowheads) and "Paste styles" (applying the captured style to every selected element as one undoable step). "Paste styles" SHALL be disabled until a style has been copied.

#### Scenario: Style transfers between shapes
- **WHEN** the user copies the styles of a red dashed rectangle, selects a
  plain ellipse, and pastes styles
- **THEN** the ellipse SHALL take the red dashed stroke (and the other copied
  properties), and undo SHALL restore its previous style
