import Foundation

/// Device form factor derived from the editor's pixel size, mirroring the
/// breakpoints in `packages/common/src/editorInterface.ts`.
public enum FormFactor: String, Sendable {
    case phone
    case tablet
    case desktop
}

/// Layout-relevant device characteristics. The UI uses this to choose between
/// the compact (iPhone: bottom toolbar, sheets) and regular (iPad: side panels)
/// presentations.
public struct DeviceClass: Sendable, Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public var formFactor: FormFactor {
        if width <= 599 { return .phone }
        if width <= 1180 { return .tablet }
        return .desktop
    }

    public var isLandscape: Bool {
        width > height
    }

    /// iPhone-style compact UI (bottom toolbar, full-screen sheets).
    public var usesCompactLayout: Bool {
        formFactor == .phone
    }

    /// Whether a docked side panel fits (iPad landscape / desktop).
    public var canDockSidebar: Bool {
        formFactor == .desktop || (formFactor == .tablet && isLandscape)
    }
}
