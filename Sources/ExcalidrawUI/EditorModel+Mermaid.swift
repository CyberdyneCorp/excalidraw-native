import ExcalidrawMath

public extension EditorModel {
    /// Parse `mermaidText` as a Mermaid flowchart and insert it, centred, then
    /// close the input. No-op (leaves the sheet open) if it doesn't parse.
    func commitMermaid() {
        let center = viewport.viewToScene(Point(canvasSize.width / 2, canvasSize.height / 2))
        if controller.insertMermaid(mermaidText, at: Point(center.x - 200, center.y - 150)) {
            activeTool = .selection
            controller.setTool(.selection)
            revision += 1
            showMermaidInput = false
            mermaidText = ""
        }
    }
}
