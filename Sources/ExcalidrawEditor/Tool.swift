import ExcalidrawModel
import Foundation

/// The active editing tool. Phase 3 covers selection plus the box/line shape
/// tools; arrow, freedraw, text and image arrive in Phase 4.
public enum Tool: String, Sendable, CaseIterable {
    case selection
    case rectangle
    case diamond
    case ellipse
    case line

    /// The element kind a shape tool creates, or `nil` for the selection tool.
    var elementKind: ElementKind? {
        switch self {
        case .selection: return nil
        case .rectangle: return .rectangle
        case .diamond: return .diamond
        case .ellipse: return .ellipse
        case .line: return .line(LinearProperties())
        }
    }

    var isShape: Bool { elementKind != nil }
}
