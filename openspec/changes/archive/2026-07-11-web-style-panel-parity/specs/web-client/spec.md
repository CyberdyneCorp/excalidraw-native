## ADDED Requirements

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
