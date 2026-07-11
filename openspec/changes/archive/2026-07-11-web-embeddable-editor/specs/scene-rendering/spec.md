## ADDED Requirements

### Requirement: Configurable overlay colours

The interaction overlay SHALL accept its colours through render options — selection accent (box, handles, linear-edit points), suggested-binding highlight, snap guides, and handle fill — falling back to the current excalidraw-like defaults when not supplied. Colours SHALL affect only the overlay pass; scene elements and the model SHALL be unaffected.

#### Scenario: Overriding the selection accent
- **WHEN** the overlay is rendered with a custom accent colour and a selection
- **THEN** the selection box and handles SHALL be drawn in that colour, and the
  scene elements SHALL be drawn exactly as before
