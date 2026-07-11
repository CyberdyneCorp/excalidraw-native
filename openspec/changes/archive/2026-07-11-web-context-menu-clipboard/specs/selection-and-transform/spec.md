## ADDED Requirements

### Requirement: Style capture and application

The editor SHALL capture an element's style properties (stroke colour, background colour, fill style, stroke width, stroke style, roughness, roundness, opacity, and — where applicable — font family, font size, text alignment, and start/end arrowheads) as a standalone value, and SHALL apply such a captured style to every selected element as a single undoable step, leaving geometry, ids, bindings, and group membership untouched. Properties that do not apply to an element's type SHALL be ignored for that element.

#### Scenario: Applying a captured style
- **WHEN** a style captured from a dashed, semi-transparent rectangle is
  applied to a selected ellipse and arrow
- **THEN** both SHALL take the stroke, background, fill, width, style,
  roughness, and opacity, their positions and sizes SHALL be unchanged, and a
  single undo SHALL revert all of them

### Requirement: Wrap selection in a frame

The editor SHALL create a frame enclosing the current selection (with a margin), adopt the selected elements as its children via the existing frame-membership rules, and select the new frame — as one undoable step.

#### Scenario: Wrapping two shapes
- **WHEN** two shapes are selected and wrapped in a frame
- **THEN** a frame element SHALL be created enclosing both, both SHALL become
  its children (moving the frame moves them), and undo SHALL remove the frame
  and restore the previous selection
