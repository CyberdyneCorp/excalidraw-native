## ADDED Requirements

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
