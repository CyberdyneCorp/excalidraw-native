# Web Client Host

## Purpose

The Svelte 5 web shell that wraps the pure editor core for the browser — the
analogue of the iOS Platform UX layer. It covers the `Canvas` host's mouse/wheel
navigation, the right-click context menu over the canvas, and the host wiring
that keeps the on-canvas text editor visually consistent with the renderer. The
drawing, selection, rendering, and collaboration behaviours themselves are the
shared capability specs; this captures only the web-host-specific concerns.
## Requirements
### Requirement: Canvas navigation (wheel zoom, middle-mouse pan)

The web canvas SHALL zoom in/out on the mouse wheel, anchored at the cursor so
the scene point under the pointer stays fixed (`store.zoomAtScreenPoint`), and
SHALL pan the view while the middle mouse button is held and dragged, regardless
of the active tool. Shift+wheel SHALL pan horizontally. The right mouse button
SHALL NOT draw, select, or otherwise reach the editor — it is reserved for the
context menu. (src: web/apps/web/src/lib/Canvas.svelte, web/packages/excalidraw-svelte/src/svelte/editor-store.ts)

#### Scenario: Wheel zooms around the cursor
- GIVEN the canvas at 100% zoom with the cursor over a scene point
- WHEN the wheel is scrolled up then down
- THEN the zoom SHALL increase then decrease, and the scene point under the
  cursor SHALL remain fixed (src: web/apps/web/e2e/pan-zoom-contextmenu.spec.ts)

#### Scenario: Middle-mouse drag pans the canvas
- GIVEN the canvas with any active tool
- WHEN the middle mouse button is pressed and dragged
- THEN the viewport SHALL scroll with the drag and no element SHALL be created
  or selected (src: web/apps/web/e2e/pan-zoom-contextmenu.spec.ts)

#### Scenario: Right button does not disturb the selection
- GIVEN one or more selected elements
- WHEN the right mouse button is pressed on the canvas
- THEN the selection SHALL be preserved (the right button only opens the context
  menu) (src: web/apps/web/src/lib/Canvas.svelte)

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

### Requirement: Double-click creates or edits a container label

Double-clicking a bindable container (rectangle, diamond, ellipse) with the selection tool SHALL open the on-canvas text editor for that container's bound label: when the container already has a bound text the editor SHALL open with its current content, and when it has none the system SHALL create an empty bound text element (centered, `containerId` set, container registered in `boundElements`) and open the editor on it. Committing a non-empty value SHALL render the label centered in the container; committing an empty value on a newly created label SHALL remove the label element and leave the container unchanged.

#### Scenario: Double-click adds a label to a plain shape
- **WHEN** the user double-clicks inside a rectangle that has no bound text
- **THEN** a text editor SHALL open over the shape, and typing "Hello" then
  committing SHALL leave a bound text "Hello" centered in the rectangle

#### Scenario: The editor caret starts centred in the shape
- **WHEN** the label editor opens over a container (double-clicked shape,
  sticky note, or table cell)
- **THEN** the caret SHALL sit at the container's centre — text centred
  horizontally and the input region vertically centred — and SHALL stay
  centred as lines are added

#### Scenario: Double-click edits an existing label
- **WHEN** the user double-clicks a shape that already has a bound label
- **THEN** the editor SHALL open pre-filled with the label text, and the
  committed edit SHALL replace the label content

#### Scenario: Cancelling a new label leaves no orphan
- **WHEN** the user double-clicks a plain shape and commits without typing
- **THEN** no text element SHALL remain in the scene and the container's
  `boundElements` SHALL not reference a deleted label

#### Scenario: Labels interop with files and collaboration unchanged
- **WHEN** a label is created and the scene is saved to `.excalidraw`, synced
  over the relay protocol, or synced over Yjs
- **THEN** the label SHALL travel as an ordinary schema-v2 text element
  (`containerId` set, container's `boundElements` updated) with no new file
  fields, message types, or Yjs mapping rules, and SHALL open correctly on
  excalidraw.com and the iOS client

### Requirement: Container labels fit their container

A bound label SHALL always fit inside its container: on commit the raw input (preserved in `originalText`) SHALL be word-wrapped to the container's inner width (over-long words broken by character), and if the wrapped block is taller than the container the container SHALL grow around its centre to fit it. Resizing a labelled container SHALL scale the label's font size by the container's size change (area ratio) and re-wrap the label to the new width, so a bigger sticky note shows bigger text and a smaller one smaller text, never overflowing.

#### Scenario: A long label wraps and the note grows
- **WHEN** the user types a label wider than the sticky note
- **THEN** the committed label SHALL wrap to the note's width, the note SHALL
  grow vertically if needed, and no glyph SHALL render outside the note

#### Scenario: Resizing the note scales its text
- **WHEN** the user drags a labelled note's corner handle outward, then inward
- **THEN** the label's font size SHALL grow, then shrink, with the text
  re-wrapped to keep fitting the note at every size

### Requirement: Double-click on empty canvas creates a text element

Double-clicking empty canvas with the selection tool SHALL create a new unbound text element at the double-clicked scene point and open the on-canvas text editor for it. Committing a non-empty value SHALL keep the text element; committing an empty value SHALL remove it (matching the existing empty-unbound text rule in `drawing-tools`).

#### Scenario: Quick text via double-click
- **WHEN** the user double-clicks an empty area of the canvas and types
  "Quick text" then commits
- **THEN** a text element "Quick text" SHALL exist at that point and remain
  after the editor closes

#### Scenario: Existing double-click behaviors keep priority
- **WHEN** the user double-clicks a chart group, a line/arrow, or a container
  with bound text
- **THEN** chart editing, linear point editing, or label editing SHALL begin
  respectively, and no canvas text element SHALL be created

### Requirement: Number-key tool shortcuts

The web client SHALL select tools with excalidraw's number shortcuts — 1 selection, 2 rectangle, 3 diamond, 4 ellipse, 5 arrow, 6 line, 7 draw (freedraw), 8 text, 9 insert image, 0 eraser — alongside the existing letter shortcuts, and the toolbar SHALL display each tool's shortcut as a badge on its button. Number keys with a platform modifier held (Cmd/Ctrl) SHALL NOT switch tools.

#### Scenario: Digits select the excalidraw tool order
- **WHEN** the user presses "2", "5", then "1" with no editor open
- **THEN** the active tool SHALL become rectangle, then arrow, then selection

### Requirement: Hand tool pans the canvas

With the hand tool active, pointer drags SHALL pan the viewport (scroll follows the drag) and SHALL NOT create, select, or modify any element.

#### Scenario: Hand drag scrolls the view
- **WHEN** the hand tool is active and the user drags right and down
- **THEN** the viewport scroll SHALL follow the drag and the scene SHALL be
  unchanged

### Requirement: Clicking outside commits the open text editor

While an on-canvas text editor is open (text tool, canvas double-click, or a container label), a pointer press on the canvas SHALL commit the edit exactly as Enter does, and that press SHALL be consumed — it SHALL NOT draw, change the selection, or open another editor. Enter, Escape, and focus loss SHALL commit identically.

#### Scenario: Text-tool text commits on an outside click
- **WHEN** the user picks the text tool, clicks the canvas, types "Hi", and
  clicks elsewhere on the canvas
- **THEN** a single text element "Hi" SHALL exist, no second editor or text
  element SHALL be created by the outside click, and the selection tool SHALL
  be active

### Requirement: Tool shortcuts are inert while editing text

While any on-canvas text editor (label, canvas text, table cell, sticky note) is open or focused, single-letter tool shortcuts and other single-key editor commands (delete/backspace element deletion, tool switching) SHALL NOT fire; keystrokes SHALL go to the editor only. Escape SHALL commit/close the editor without changing the active tool.

#### Scenario: Typing a label never switches tools
- **WHEN** a text editor is open and the user types "Hello"
- **THEN** the active tool SHALL be unchanged after the editor closes (the
  "o" MUST NOT activate the ellipse tool)

### Requirement: Style panel control parity

The style panel SHALL offer excalidraw's control set: stroke and background swatch palettes (five preset colours each plus a custom colour picker), stroke width presets (thin/bold/extra-bold), stroke style (solid/dashed/dotted), sloppiness (architect/artist/cartoonist), edges (sharp/round), an opacity slider (0–100), and the fill pattern selector. Each control SHALL apply to the current selection when one exists and SHALL set the default for subsequently created elements, in both cases writing only standard element fields (`strokeColor`, `backgroundColor`, `strokeWidth`, `strokeStyle`, `roughness`, `roundness`, `opacity`, `fillStyle`).

#### Scenario: Styling a selected shape
- **WHEN** a rectangle is selected and the user picks the dashed stroke
  style, cartoonist sloppiness, and 50 opacity
- **THEN** the rectangle's `strokeStyle`, `roughness`, and `opacity` SHALL
  update accordingly and render immediately

#### Scenario: Styling the next element
- **WHEN** nothing is selected and the user picks a red stroke swatch, then
  draws an ellipse
- **THEN** the new ellipse SHALL be created with the red stroke

### Requirement: Contextual text and arrow sections

The style panel SHALL show a text section (font family: hand-drawn/normal/code; font size: S/M/L/XL; text alignment: left/centre/right) only when the selection contains text or the text tool is active, and an arrow section (arrow type: straight/curved/elbow; start and end arrowhead pickers: none/arrow/triangle/bar/dot/diamond) only when the selection contains a linear element or a linear tool is active. Arrow type SHALL map to the standard fields (`elbowed`, `roundness`); arrowheads SHALL write `startArrowhead`/`endArrowhead`.

#### Scenario: Font controls on selected text
- **WHEN** a text element is selected and the user picks font size L and
  centre alignment
- **THEN** the text element's `fontSize` and `textAlign` SHALL update and
  its measured size SHALL be recomputed

#### Scenario: Arrowheads on a selected arrow
- **WHEN** an arrow is selected and the user sets the start arrowhead to
  triangle and the end arrowhead to none
- **THEN** the arrow SHALL render a triangle head at its start and no head
  at its end, and the values SHALL persist through save/reload

#### Scenario: Sections gate on context
- **WHEN** a rectangle is selected
- **THEN** the text and arrow sections SHALL NOT be shown

### Requirement: Panel reflects the selection

When the selection changes, the style panel's controls SHALL reflect the selected element's current values (the first selected element when multiple are selected); with no selection they SHALL reflect the defaults for the next element. Changing a control SHALL never reorder, deselect, or otherwise disturb the selection.

#### Scenario: Selecting an element loads its style into the panel
- **WHEN** the user selects a dashed red rectangle
- **THEN** the panel SHALL show the red stroke swatch active, the dashed
  stroke style active, and the rectangle SHALL remain selected while any
  control is changed

### Requirement: Tool lock keeps the active tool

The toolbar SHALL offer a lock toggle ("keep tool active"): with lock on, finishing an element (drag- or click-created) SHALL keep the current drawing tool active instead of reverting to selection; with lock off the existing revert behaviour applies. The lock state SHALL be visible on the toggle.

#### Scenario: Locked tool draws repeatedly
- **WHEN** the user enables tool lock, picks the rectangle tool, and draws two rectangles
- **THEN** both rectangles SHALL be created without re-picking the tool, and disabling the lock SHALL restore revert-to-selection

### Requirement: App menu with file flows

A menu button SHALL open an app menu offering: Open (accepts `.excalidraw` JSON and PNG files with an embedded scene, replacing the current scene), Save (downloads the scene as `.excalidraw`), Export image (opens the export dialog), Reset canvas (clears the scene as a single undoable step), theme toggle, and Help. Opening a PNG without an embedded scene SHALL be rejected with a visible message and leave the scene unchanged.

#### Scenario: Open restores a saved document
- **WHEN** the user saves a two-element scene and later opens the downloaded `.excalidraw` file via the menu
- **THEN** the scene SHALL contain the same two elements

#### Scenario: Reset canvas is undoable
- **WHEN** the user resets the canvas from the menu and presses undo
- **THEN** the scene SHALL be empty after the reset and fully restored after the undo

### Requirement: Export image dialog

The export dialog SHALL offer: format (PNG or SVG), scale (1×/2×/3×, PNG only), background on/off (off exports a transparent PNG or an SVG without a background rectangle), selection-only (enabled only when a selection exists), and embed scene (PNG only, on by default). Exports SHALL use canonical (light-theme) colours and SHALL cover the chosen content's bounds with a margin.

#### Scenario: Transparent selection-only PNG at 2×
- **WHEN** the user selects one of two shapes and exports PNG at 2× with background off and selection-only on
- **THEN** the downloaded PNG SHALL contain only the selected shape at double resolution with transparent pixels around it

### Requirement: PNG scene-embed round-trip

Exporting a PNG with "embed scene" SHALL write the scene into the PNG using the excalidraw-compatible `tEXt` codec, and opening such a PNG via the app menu SHALL restore the identical scene for further editing.

#### Scenario: Exported PNG reopens as an editable scene
- **WHEN** the user exports a labelled rectangle and an arrow as an embedded PNG, resets the canvas, and opens the PNG
- **THEN** the scene SHALL contain the rectangle, its label, and the arrow with identical geometry and bindings

### Requirement: Welcome screen

An empty canvas SHALL show a welcome overlay (product hint, tool hint, shortcut pointer) that never intercepts canvas input; it SHALL disappear once the scene has elements or a drawing tool is picked, and SHALL NOT reappear over a non-empty scene.

#### Scenario: Welcome clears when work starts
- **WHEN** the app loads with an empty scene and the user picks the rectangle tool
- **THEN** the overlay SHALL be visible before and hidden after, and drawing SHALL work identically in both states

### Requirement: Help overlay

Pressing `?` (or choosing Help in the menu) SHALL open an overlay listing the keyboard shortcuts (tools with digits/letters, edit commands, canvas navigation); Escape or an outside click SHALL dismiss it. The shortcut list SHALL match the actual bindings.

#### Scenario: Help opens and closes
- **WHEN** the user presses `?` and then Escape
- **THEN** the shortcut overlay SHALL appear (listing at least the tool digits 1–8) and then close, leaving the scene untouched

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

### Requirement: Flowchart quick-create

With exactly one bindable shape selected, pressing `Cmd/Ctrl` + an arrow key SHALL create a new node of the same kind offset in that direction, connected to the source by a bound arrow, and select the new node — so a flowchart can be built without leaving the keyboard. Hovering a selected shape SHALL additionally show four quick-arrow buttons (one per side); clicking one SHALL perform the same spawn in that direction.

#### Scenario: Keyboard spawns a connected node
- **WHEN** a rectangle is selected and the user presses Cmd/Ctrl+Right
- **THEN** a second rectangle SHALL appear to its right, an arrow SHALL connect
  the two (bound at both ends), and the new rectangle SHALL be selected

#### Scenario: Quick-arrow button spawns downward
- **WHEN** a selected shape's bottom quick-arrow button is clicked
- **THEN** a connected node SHALL be created below it

### Requirement: Freehand shape recognition

A selected freedraw stroke SHALL offer a "Snap to shape" action (context menu) that replaces it with the recognized primitive (rectangle, ellipse, diamond, line, or arrow) when one is recognized, preserving position and style, as one undoable step; when nothing is recognized the stroke SHALL be left unchanged.

#### Scenario: A rough rectangle snaps to a rectangle
- **WHEN** the user sketches a rough four-corner loop with the draw tool and
  chooses "Snap to shape"
- **THEN** the freedraw element SHALL be replaced by a rectangle element in the
  same place, and undo SHALL restore the stroke

### Requirement: Canvas navigation helpers

The client SHALL offer: **zoom to fit** (`Shift+1`, the zoom island, and the empty-canvas menu) fitting all content in view; a **scroll-back-to-content** pill shown only when the scene has elements and none of the content bounds intersect the viewport, which recentres the view when clicked; and **grid** and **snap** toggles whose states are visible, where the grid renders behind the scene and snapping guides element moves.

#### Scenario: Scroll-back pill appears and recentres
- **WHEN** the user draws a shape and then pans until it is off-screen
- **THEN** the pill SHALL appear, and clicking it SHALL bring the content back
  into view (the pill SHALL then disappear)

#### Scenario: Grid and snap toggles
- **WHEN** the user enables the grid and the snap toggle
- **THEN** the canvas SHALL render a grid and dragging an element SHALL snap it
  to nearby elements, and disabling both SHALL restore the plain behaviour

### Requirement: Zen mode

`Alt+Z` (and a command-palette entry) SHALL toggle zen mode: all chrome except the canvas and the zoom island SHALL be hidden, while every tool remains usable from the keyboard. Toggling back SHALL restore the chrome.

#### Scenario: Zen mode hides the chrome
- **WHEN** the user presses Alt+Z
- **THEN** the toolbar, style panel, and menus SHALL be hidden, drawing with a
  keyboard-selected tool SHALL still work, and Alt+Z SHALL restore them

### Requirement: Command palette

`Cmd/Ctrl+K` SHALL open a searchable command palette listing tools, generators, view toggles, edit commands, and file flows. Typing SHALL filter the list, Up/Down SHALL move the highlight, Enter SHALL run the highlighted command, and Escape SHALL close the palette. Running a command SHALL have the same effect as invoking it from its menu or shortcut.

#### Scenario: Palette runs a command
- **WHEN** the user presses Cmd/Ctrl+K, types "rect", and presses Enter
- **THEN** the palette SHALL close and the rectangle tool SHALL be active

