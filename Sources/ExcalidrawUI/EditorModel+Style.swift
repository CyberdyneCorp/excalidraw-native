import ExcalidrawEditor
import ExcalidrawModel

/// Stroke / fill / text style setters — applied to the current selection and
/// remembered for the next created element. (Split out of `EditorModel.swift`.)
@MainActor
public extension EditorModel {
    func setStrokeColor(_ color: String) {
        strokeColor = color
        controller.currentItem.strokeColor = color
        applyToSelection { $0.base.strokeColor = color }
    }

    func setStrokeWidth(_ width: Double) {
        strokeWidth = width
        controller.currentItem.strokeWidth = width
        applyToSelection { $0.base.strokeWidth = width }
    }

    func setBackgroundColor(_ color: String) {
        backgroundColor = color
        controller.currentItem.backgroundColor = color
        applyToSelection { $0.base.backgroundColor = color }
    }

    func setFillStyle(_ style: ExcalidrawModel.FillStyle) {
        fillStyle = style
        controller.currentItem.fillStyle = style
        applyToSelection { $0.base.fillStyle = style }
    }

    func setStrokeStyle(_ style: ExcalidrawModel.StrokeStyle) {
        strokeStyle = style
        controller.currentItem.strokeStyle = style
        applyToSelection { $0.base.strokeStyle = style }
    }

    func setOpacity(_ value: Double) {
        opacity = value
        controller.currentItem.opacity = value
        applyToSelection { $0.base.opacity = value }
    }

    /// Set the hand-drawn roughness (0 architect, 1 artist, 2 cartoonist).
    func setRoughness(_ value: Double) {
        roughness = value
        controller.currentItem.roughness = value
        applyToSelection { $0.base.roughness = value }
    }

    /// Toggle rounded edges/corners on the selection and for new elements.
    func setEdgesRound(_ round: Bool) {
        edgesRound = round
        controller.currentItem.roundEdges = round
        applyToSelection { element in
            element.base.roundness = round ? Roundness(type: roundnessType(for: element)) : nil
        }
    }

    private func roundnessType(for element: ExcalidrawElement) -> Int {
        switch element.kind {
        case .line, .arrow: RoundnessType.proportionalRadius
        default: RoundnessType.adaptiveRadius
        }
    }

    func setFontFamily(_ family: Int) {
        fontFamily = family
        controller.currentItem.fontFamily = family
        controller.updateSelectedText { $0.fontFamily = family }
        revision += 1
    }

    func setFontSize(_ size: Double) {
        fontSize = size
        controller.currentItem.fontSize = size
        controller.updateSelectedText { $0.fontSize = size }
        revision += 1
    }

    func setElbowed(_ elbowed: Bool) {
        self.elbowed = elbowed
        controller.setElbowed(elbowed)
        revision += 1
    }
}
