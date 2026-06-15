import ExcalidrawEditor
import ExcalidrawMath
import ExcalidrawModel
import ExcalidrawRender
import SwiftUI

/// Bridges the pure `EditorController` to SwiftUI: forwards pointer events
/// (converting view → scene coordinates), owns the viewport, and republishes a
/// `revision` so the canvas redraws after each change.
@MainActor
public final class EditorModel: ObservableObject {
    public let controller: EditorController
    let renderer = SceneRenderer()

    @Published public var viewport: Viewport
    @Published public private(set) var revision = 0
    @Published public var activeTool: Tool = .selection
    @Published public var strokeColor: String = "#1e1e1e"
    @Published public var strokeWidth: Double = 2
    @Published public var backgroundColor: String = "transparent"
    @Published public var fillStyle: ExcalidrawModel.FillStyle = .hachure
    @Published public var strokeStyle: ExcalidrawModel.StrokeStyle = .solid
    @Published public var opacity: Double = 100

    /// On-canvas text editing state.
    @Published public var editingTextID: String?
    @Published public var editingText: String = ""
    @Published public var editingTextOrigin: CGPoint = .zero

    public init(scene: ExcalidrawModel.Scene = ExcalidrawModel.Scene(), viewport: Viewport = Viewport()) {
        controller = EditorController(scene: scene)
        controller.zoom = viewport.zoom
        self.viewport = viewport
    }

    // MARK: Pointer input (view coordinates in)

    public func pointer(
        _ phase: PointerPhase, at viewPoint: CGPoint, type: PointerType = .mouse,
        pressure: Double = 0.5, shift: Bool = false, alt: Bool = false, toggle: Bool = false
    ) {
        let scenePoint = viewport.viewToScene(Point(viewPoint.x, viewPoint.y))

        // The text tool creates + edits text on tap rather than dragging.
        if activeTool == .text {
            if phase == .down { beginTextEditing(at: viewPoint, scenePoint: scenePoint) }
            return
        }

        let event = PointerEvent(
            scenePoint: scenePoint, phase: phase, type: type,
            pressure: pressure, shift: shift, alt: alt, toggleSelection: toggle
        )
        switch phase {
        case .down: controller.pointerDown(event)
        case .move: controller.pointerMove(event)
        case .up:
            controller.pointerUp(event)
            activeTool = controller.activeTool // tool may revert after creating
        }
        revision += 1
    }

    // MARK: Viewport (two-finger pan / pinch)

    public func panZoom(translation: CGSize, scale: Double) {
        var v = viewport
        let range = ExcalidrawRender.zoomRange
        v.zoom = min(max(viewport.zoom * scale, range.lowerBound), range.upperBound)
        v.scrollX = viewport.scrollX + translation.width / v.zoom
        v.scrollY = viewport.scrollY + translation.height / v.zoom
        viewport = v
        controller.zoom = v.zoom
        revision += 1
    }

    // MARK: Commands

    public func select(tool: Tool) {
        controller.setTool(tool)
        activeTool = tool
        revision += 1
    }

    public func setStrokeColor(_ color: String) {
        strokeColor = color
        controller.currentItem.strokeColor = color
        applyToSelection { $0.base.strokeColor = color }
    }

    public func setStrokeWidth(_ width: Double) {
        strokeWidth = width
        controller.currentItem.strokeWidth = width
        applyToSelection { $0.base.strokeWidth = width }
    }

    public func setBackgroundColor(_ color: String) {
        backgroundColor = color
        controller.currentItem.backgroundColor = color
        applyToSelection { $0.base.backgroundColor = color }
    }

    public func setFillStyle(_ style: ExcalidrawModel.FillStyle) {
        fillStyle = style
        controller.currentItem.fillStyle = style
        applyToSelection { $0.base.fillStyle = style }
    }

    public func setStrokeStyle(_ style: ExcalidrawModel.StrokeStyle) {
        strokeStyle = style
        controller.currentItem.strokeStyle = style
        applyToSelection { $0.base.strokeStyle = style }
    }

    public func setOpacity(_ value: Double) {
        opacity = value
        controller.currentItem.opacity = value
        applyToSelection { $0.base.opacity = value }
    }

    // MARK: Action passthroughs

    public func group() { controller.group(); revision += 1 }
    public func duplicate() { controller.duplicate(); revision += 1 }
    public func bringToFront() { controller.reorder(.front); revision += 1 }
    public func sendToBack() { controller.reorder(.back); revision += 1 }
    public func align(_ alignment: EditorController.Alignment) { controller.align(alignment); revision += 1 }

    public func undo() { controller.undo(); revision += 1 }
    public func redo() { controller.redo(); revision += 1 }
    public func deleteSelected() { controller.deleteSelected(); revision += 1 }

    public func exportPNG() -> Data? {
        Exporter.pngData(controller.scene)
    }

    public func exportSVG() -> String {
        SVGExporter.svg(controller.scene)
    }

    // MARK: Text editing

    func beginTextEditing(at viewPoint: CGPoint, scenePoint: Point) {
        let id = controller.createText(at: scenePoint)
        editingTextID = id
        editingText = ""
        editingTextOrigin = viewPoint
        revision += 1
    }

    public func commitText() {
        if let id = editingTextID {
            controller.setText(id: id, editingText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        editingTextID = nil
        editingText = ""
        if !controller.toolLocked {
            controller.setTool(.selection)
            activeTool = .selection
        }
        revision += 1
    }

    // MARK: Image insert

    /// Decode image `data`, build a data URL, and insert it centred in the view.
    public func insertImage(data: Data, mimeType: String, viewSize: CGSize) {
        guard let image = ImageDecoder.decode(dataURL: "data:\(mimeType);base64,\(data.base64EncodedString())") else {
            return
        }
        let maxDimension = 320.0
        let scale = min(1, maxDimension / Double(max(image.width, image.height)))
        let width = Double(image.width) * scale
        let height = Double(image.height) * scale
        let center = viewport.viewToScene(Point(viewSize.width / 2, viewSize.height / 2))
        let dataURL = "data:\(mimeType);base64,\(data.base64EncodedString())"
        controller.insertImage(
            dataURL: dataURL, mimeType: mimeType,
            at: Point(center.x - width / 2, center.y - height / 2), width: width, height: height
        )
        activeTool = .selection
        controller.setTool(.selection)
        revision += 1
    }

    /// Apply a style change to the current selection as one undo step.
    private func applyToSelection(_ change: (inout ExcalidrawElement) -> Void) {
        controller.updateSelected(change)
        revision += 1
    }
}
