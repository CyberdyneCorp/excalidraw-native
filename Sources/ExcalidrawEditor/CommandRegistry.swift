import Foundation

/// A named, searchable command for the command palette (⌘K).
public struct PaletteCommand: Sendable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var command: EditorCommand

    public init(id: String, title: String, command: EditorCommand) {
        self.id = id
        self.title = title
        self.command = command
    }
}

/// The catalog of palette commands and a simple subsequence search.
public enum CommandRegistry {
    public static let all: [PaletteCommand] = [
        .init(id: "tool.selection", title: "Selection tool", command: .selectTool(.selection)),
        .init(id: "tool.rectangle", title: "Rectangle tool", command: .selectTool(.rectangle)),
        .init(id: "tool.diamond", title: "Diamond tool", command: .selectTool(.diamond)),
        .init(id: "tool.ellipse", title: "Ellipse tool", command: .selectTool(.ellipse)),
        .init(id: "tool.arrow", title: "Arrow tool", command: .selectTool(.arrow)),
        .init(id: "tool.line", title: "Line tool", command: .selectTool(.line)),
        .init(id: "tool.freedraw", title: "Draw tool", command: .selectTool(.freedraw)),
        .init(id: "tool.text", title: "Text tool", command: .selectTool(.text)),
        .init(id: "tool.eraser", title: "Eraser tool", command: .selectTool(.eraser)),
        .init(id: "edit.undo", title: "Undo", command: .undo),
        .init(id: "edit.redo", title: "Redo", command: .redo),
        .init(id: "edit.delete", title: "Delete selection", command: .delete),
        .init(id: "edit.duplicate", title: "Duplicate", command: .duplicate),
        .init(id: "edit.selectAll", title: "Select all", command: .selectAll),
        .init(id: "edit.group", title: "Group selection", command: .group),
        .init(id: "edit.ungroup", title: "Ungroup selection", command: .ungroup),
        .init(id: "edit.copy", title: "Copy", command: .copy),
        .init(id: "edit.paste", title: "Paste", command: .paste),
        .init(id: "order.front", title: "Bring to front", command: .bringToFront),
        .init(id: "order.back", title: "Send to back", command: .sendToBack),
        .init(id: "view.zoomIn", title: "Zoom in", command: .zoomIn),
        .init(id: "view.zoomOut", title: "Zoom out", command: .zoomOut),
        .init(id: "view.zoomToFit", title: "Zoom to fit", command: .zoomToFit),
        .init(id: "view.resetZoom", title: "Reset zoom", command: .resetZoom)
    ]

    /// Subsequence (fuzzy) search over command titles. Empty query returns all.
    public static func search(_ query: String) -> [PaletteCommand] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return all }
        return all.filter { isSubsequence(trimmed, of: $0.title.lowercased()) }
    }

    static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var it = haystack.makeIterator()
        for char in needle {
            var matched = false
            while let next = it.next() {
                if next == char { matched = true; break }
            }
            if !matched { return false }
        }
        return true
    }
}
