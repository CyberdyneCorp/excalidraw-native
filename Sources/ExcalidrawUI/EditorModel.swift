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

    public func undo() { controller.undo(); revision += 1 }
    public func redo() { controller.redo(); revision += 1 }
    public func deleteSelected() { controller.deleteSelected(); revision += 1 }

    public func exportPNG() -> Data? {
        Exporter.pngData(controller.scene)
    }

    /// Apply a style change to the current selection as one undo step.
    private func applyToSelection(_ change: (inout ExcalidrawElement) -> Void) {
        controller.updateSelected(change)
        revision += 1
    }
}
