## ADDED Requirements

### Requirement: Export background override

The renderer SHALL accept an optional background override for a render pass: `"transparent"` (no background fill) or a fixed colour, taking precedence over the scene's view background and theme default for that pass only. On-canvas rendering without the override SHALL be unchanged, and the override SHALL never modify the scene model.

#### Scenario: Transparent export pass
- **WHEN** a scene is rendered with the transparent background override
- **THEN** no background SHALL be painted (pixels outside elements stay transparent) while the same scene rendered without the override keeps the theme background
