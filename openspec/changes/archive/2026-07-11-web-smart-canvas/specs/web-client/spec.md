## ADDED Requirements

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
