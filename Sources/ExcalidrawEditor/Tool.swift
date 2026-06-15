import ExcalidrawModel
import Foundation

/// The active editing tool.
public enum Tool: String, Sendable, CaseIterable {
    case selection
    case rectangle
    case diamond
    case ellipse
    case line
    case arrow
    case freedraw
    case text
    case eraser
    case hand

    /// The element kind a shape tool creates, or `nil` for non-creating tools.
    var elementKind: ElementKind? {
        switch self {
        case .rectangle: return .rectangle
        case .diamond: return .diamond
        case .ellipse: return .ellipse
        case .line: return .line(LinearProperties())
        case .arrow: return .arrow(ArrowProperties())
        case .freedraw: return .freedraw(FreedrawProperties())
        case .selection, .eraser, .hand, .text: return nil
        }
    }

    var isShape: Bool { elementKind != nil }
}
