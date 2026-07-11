## ADDED Requirements

### Requirement: Published editor components

The package SHALL publish Svelte components from a `./ui` subpath: `Excalidraw` (the complete editor — canvas plus chrome) and `ExcalidrawCanvas` (canvas and interaction overlay only, no chrome), such that a client can render a working editor with a single component and no UI code of their own. The headless subpaths (`./editor`, `./render`, `./model`, `./geometry`, `./math`, `./protocol`) SHALL remain usable without Svelte, and `svelte` SHALL be a peer dependency rather than a hard dependency of those paths.

#### Scenario: A client renders the full editor
- **WHEN** a client imports `Excalidraw` from the package's `./ui` subpath and
  renders it with no props
- **THEN** a complete, working editor SHALL appear (toolbar, canvas, panels)
  with the same behaviour as the reference app

#### Scenario: A client renders only the canvas
- **WHEN** a client renders `ExcalidrawCanvas`
- **THEN** the canvas and its interaction overlay SHALL render with no chrome,
  and the client SHALL be able to drive it through the store it receives

### Requirement: Component props

`Excalidraw` SHALL accept: `initialData` (a scene or `.excalidraw` document loaded on mount), `theme` (`"light" | "dark"`), `viewMode` (read-only: no tool selection, creation, or editing — panning and zooming remain), `gridMode`, `zenMode`, `uiOptions` (see below), and the callbacks `onReady(store)` (invoked once with the live `EditorStore`) and `onChange(scene)` (invoked after every committed edit). Props that mirror store state SHALL stay in sync when the host changes them.

#### Scenario: Read-only view mode
- **WHEN** the component is rendered with `viewMode` enabled
- **THEN** the drawing tools SHALL be unavailable and pointer drags SHALL NOT
  create or modify elements, while panning and zooming still work

#### Scenario: Host receives the store and edits
- **WHEN** a client passes `onReady` and `onChange`
- **THEN** `onReady` SHALL receive the live store exactly once, and `onChange`
  SHALL fire with the scene after each committed edit

### Requirement: UI options

`uiOptions` SHALL let a client hide or show each piece of chrome independently: the toolbar (including *which* tools it lists), the style panel, the app menu (and its individual entries: open, save, export, reset canvas, theme, help), the context menu (and its individual commands), the command palette, the welcome screen, the zoom and undo islands, the quick-arrow buttons, and the generator entries. Hidden chrome SHALL NOT render, and hiding a piece of chrome SHALL NOT disable the underlying capability for a client driving the store directly.

#### Scenario: Hiding chrome
- **WHEN** a client renders the editor with the style panel and the app menu
  hidden, and the toolbar limited to selection, rectangle, and arrow
- **THEN** neither the panel nor the menu SHALL appear, the toolbar SHALL show
  exactly those three tools, and drawing SHALL still work

#### Scenario: Hiding does not remove capability
- **WHEN** the export entry is hidden from the menu
- **THEN** a client calling the export API on the store SHALL still be able to
  export

### Requirement: Theming contract

The component's visual design SHALL be driven by documented CSS custom properties on its root (island surface, ink, muted ink, border, hover, accent, and accent-contrast, in light and dark), which a client MAY override from their own stylesheet without forking. The interaction overlay's colours (selection accent, binding highlight, snap guides, handle fill) SHALL be configurable through the component and the renderer's overlay options rather than fixed constants.

#### Scenario: Client re-themes the editor
- **WHEN** a client overrides the documented accent and island custom
  properties, and passes overlay colours
- **THEN** the chrome and the selection/binding overlay SHALL render in the
  client's colours, in both light and dark themes

### Requirement: Host slots

The component SHALL expose slots for host-supplied chrome — at minimum extra toolbar content, a top-right area, and a footer area — so a client can add their own controls alongside (not instead of) the built-in chrome.

#### Scenario: Client adds a button
- **WHEN** a client passes content to the top-right slot
- **THEN** it SHALL render in the editor's top-right area alongside the
  built-in chrome, and receive pointer events
