import Foundation

/// A high-level editor command, the target of keyboard shortcuts and the
/// command palette.
public enum EditorCommand: Sendable, Equatable {
    case selectTool(Tool)
    case undo, redo
    case delete, duplicate, selectAll
    case group, ungroup
    case copy, cut, paste
    case bringToFront, sendToBack
    case zoomIn, zoomOut, zoomToFit, resetZoom
}

/// A key press with modifiers.
public struct KeyChord: Sendable, Equatable {
    public var key: Character
    public var command: Bool
    public var shift: Bool
    public var option: Bool

    public init(_ key: Character, command: Bool = false, shift: Bool = false, option: Bool = false) {
        self.key = Character(key.lowercased())
        self.command = command
        self.shift = shift
        self.option = option
    }
}

/// Maps key chords to editor commands. Tool letters mirror Excalidraw
/// (V/R/D/O/A/L/P/T/E/H); ⌘-combos cover edit/clipboard/zoom.
public enum Shortcuts {
    public static func command(for chord: KeyChord) -> EditorCommand? {
        if chord.command {
            return commandModified(chord)
        }
        if chord.key == "\u{8}" || chord.key == "\u{7f}" { return .delete }
        switch chord.key {
        case "v", "1": return .selectTool(.selection)
        case "r", "2": return .selectTool(.rectangle)
        case "d", "3": return .selectTool(.diamond)
        case "o", "4": return .selectTool(.ellipse)
        case "a", "5": return .selectTool(.arrow)
        case "l", "6": return .selectTool(.line)
        case "p", "x", "7": return .selectTool(.freedraw)
        case "t", "8": return .selectTool(.text)
        case "e", "0": return .selectTool(.eraser)
        case "h": return .selectTool(.hand)
        default: return nil
        }
    }

    private static func commandModified(_ chord: KeyChord) -> EditorCommand? {
        switch chord.key {
        case "z": chord.shift ? .redo : .undo
        case "c": .copy
        case "x": .cut
        case "v": .paste
        case "d": .duplicate
        case "a": .selectAll
        case "g": chord.shift ? .ungroup : .group
        case "=", "+": .zoomIn
        case "-": .zoomOut
        case "0": .resetZoom
        default: nil
        }
    }
}
