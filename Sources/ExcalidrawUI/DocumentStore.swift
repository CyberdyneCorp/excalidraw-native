import Foundation

/// File persistence helpers for the editor: an autosave slot that survives app
/// relaunch, and a recents list of opened/saved documents (stored as security-
/// scoped bookmarks). Stateless — all state lives on disk / in `UserDefaults`.
public enum DocumentStore {
    private static let recentsKey = "excalidraw.recentDocuments"
    private static let maxRecents = 12

    /// The autosave file URL in Application Support.
    public static var autosaveURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Autosave.excalidraw")
    }

    public static func saveAutosave(_ data: Data) {
        try? data.write(to: autosaveURL, options: .atomic)
    }

    public static func loadAutosave() -> Data? {
        try? Data(contentsOf: autosaveURL)
    }

    public static func clearAutosave() {
        try? FileManager.default.removeItem(at: autosaveURL)
    }

    // MARK: - Recents (security-scoped bookmarks)

    /// Record `url` as the most-recent document.
    public static func addRecent(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let bookmark = try? url.bookmarkData() else { return }

        var bookmarks = (UserDefaults.standard.array(forKey: recentsKey) as? [Data]) ?? []
        // Drop any existing bookmark resolving to the same file (compare resolved
        // paths so /var vs /private/var symlinks don't read as distinct), then
        // prepend.
        let target = url.resolvingSymlinksInPath()
        bookmarks.removeAll { resolve($0)?.url.resolvingSymlinksInPath() == target }
        bookmarks.insert(bookmark, at: 0)
        if bookmarks.count > maxRecents { bookmarks = Array(bookmarks.prefix(maxRecents)) }
        UserDefaults.standard.set(bookmarks, forKey: recentsKey)
    }

    /// The recent documents, freshest first, dropping any that no longer resolve.
    public static func recents() -> [URL] {
        let bookmarks = (UserDefaults.standard.array(forKey: recentsKey) as? [Data]) ?? []
        return bookmarks.compactMap { resolve($0)?.url }
    }

    public static func clearRecents() {
        UserDefaults.standard.removeObject(forKey: recentsKey)
    }

    private static func resolve(_ bookmark: Data) -> (url: URL, stale: Bool)? {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale
        ) else { return nil }
        return (url, stale)
    }
}
