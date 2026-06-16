import Foundation

/// Persists the user's library to a single `.excalidrawlib` file on disk and
/// reads it back. Pure Foundation file IO so it is testable with a temp URL.
public struct LibraryStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The default per-user library file in Application Support, created lazily.
    public static func defaultStore(fileManager: FileManager = .default) -> LibraryStore {
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? fileManager.temporaryDirectory
        return LibraryStore(url: base.appendingPathComponent("library.excalidrawlib"))
    }

    /// Load the library items, or an empty array if the file is missing or
    /// unreadable. Decoding errors propagate so callers can surface them.
    public func load() throws -> [[ExcalidrawElement]] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try ExcalidrawLibrary.decode(from: data).items
    }

    /// Persist the given library items, creating the parent directory as needed.
    public func save(_ items: [[ExcalidrawElement]]) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try ExcalidrawLibrary(items: items).encoded().write(to: url)
    }
}
