import ExcalidrawMath

public extension EditorModel {
    /// Insert an embeddable element carrying `embedURLText`, centred, then close
    /// the prompt. No-op (keeps the prompt open) for an empty URL.
    func commitEmbed() {
        let url = embedURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        let center = viewport.viewToScene(Point(canvasSize.width / 2, canvasSize.height / 2))
        controller.insertEmbeddable(link: url, at: center)
        activeTool = .selection
        controller.setTool(.selection)
        revision += 1
        showEmbedPrompt = false
        embedURLText = ""
    }
}
