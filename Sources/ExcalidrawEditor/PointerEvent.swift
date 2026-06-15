import ExcalidrawMath
import Foundation

/// Input device kind (`PointerType` in upstream).
public enum PointerType: String, Sendable {
    case mouse
    case pen
    case touch
}

public enum PointerPhase: Sendable {
    case down
    case move
    case up
}

/// A single pointer sample, already converted to scene coordinates by the UI
/// layer so the editor logic stays independent of the viewport.
public struct PointerEvent: Sendable {
    public var scenePoint: Point
    public var phase: PointerPhase
    public var type: PointerType
    public var pressure: Double
    /// Modifier keys / gestures the UI maps in (Shift constrains, Alt resizes
    /// from centre, Cmd/Ctrl toggles selection).
    public var shift: Bool
    public var alt: Bool
    public var toggleSelection: Bool

    public init(
        scenePoint: Point, phase: PointerPhase, type: PointerType = .mouse,
        pressure: Double = 0.5, shift: Bool = false, alt: Bool = false, toggleSelection: Bool = false
    ) {
        self.scenePoint = scenePoint
        self.phase = phase
        self.type = type
        self.pressure = pressure
        self.shift = shift
        self.alt = alt
        self.toggleSelection = toggleSelection
    }
}
