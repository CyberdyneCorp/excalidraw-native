import Foundation

/// Files-app open/save, autosave (survives relaunch), and a recents list.
public extension EditorModel {
    /// Recently opened/saved documents, freshest first.
    var recentDocuments: [URL] {
        DocumentStore.recents()
    }

    /// Persist the current scene to the autosave slot (call on background).
    func autosave() {
        guard !controller.scene.visibleElements.isEmpty, let data = documentData() else { return }
        DocumentStore.saveAutosave(data)
    }

    /// On launch, restore the autosaved drawing if the canvas is still empty
    /// (so we never clobber a document the user already opened).
    func restoreAutosaveIfEmpty() {
        guard controller.scene.visibleElements.isEmpty, let data = DocumentStore.loadAutosave() else { return }
        loadDocument(data)
    }

    /// Open a `.excalidraw` file (security-scoped), replacing the current scene,
    /// and record it in recents. Returns whether it loaded.
    @discardableResult
    func openDocument(at url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return false }
        // An exported PNG with an embedded scene re-opens too.
        if url.pathExtension.lowercased() == "png", openSceneFromPNG(data) {
            DocumentStore.addRecent(url)
            return true
        }
        loadDocument(data)
        DocumentStore.addRecent(url)
        return true
    }

    /// Write the current scene to `url` and record it in recents.
    @discardableResult
    func saveDocument(to url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = documentData() else { return false }
        do {
            try data.write(to: url, options: .atomic)
            DocumentStore.addRecent(url)
            return true
        } catch {
            return false
        }
    }
}
