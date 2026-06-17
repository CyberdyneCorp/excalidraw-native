import Foundation

/// The change to a single element between two scene states. A `nil` side means
/// the element was absent (insertion when `before == nil`, removal when
/// `after == nil`).
public struct ElementChange: Equatable, Sendable {
    public var before: ExcalidrawElement?
    public var after: ExcalidrawElement?

    public init(before: ExcalidrawElement?, after: ExcalidrawElement?) {
        self.before = before
        self.after = after
    }
}

/// A reversible diff between two element lists, keyed by element id.
///
/// Phase 1 uses whole-element snapshots rather than upstream's property-level
/// partial deltas (`packages/element/src/delta.ts`). This is correct and simple
/// for local undo/redo; the finer-grained representation that collaboration
/// bandwidth needs is a later increment. AppState deltas are likewise deferred.
public struct SceneDelta: Equatable, Sendable {
    public var changes: [String: ElementChange]

    public init(changes: [String: ElementChange] = [:]) {
        self.changes = changes
    }

    public var isEmpty: Bool {
        changes.isEmpty
    }

    /// Diff `old` → `new`, recording only elements that actually changed.
    public static func between(_ old: [ExcalidrawElement], _ new: [ExcalidrawElement]) -> SceneDelta {
        let oldByID = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let newByID = Dictionary(new.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        var changes: [String: ElementChange] = [:]
        for id in Set(oldByID.keys).union(newByID.keys) where oldByID[id] != newByID[id] {
            changes[id] = ElementChange(before: oldByID[id], after: newByID[id])
        }
        return SceneDelta(changes: changes)
    }

    /// The delta that undoes this one (`before` and `after` swapped).
    public func inverse() -> SceneDelta {
        SceneDelta(changes: changes.mapValues { ElementChange(before: $0.after, after: $0.before) })
    }
}

/// Undo/redo stacks of recorded deltas (`packages/excalidraw/history.ts`).
public struct History: Sendable {
    private var undoStack: [SceneDelta] = []
    private var redoStack: [SceneDelta] = []

    public init() {}

    public var canUndo: Bool {
        !undoStack.isEmpty
    }

    public var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// Record a new change, clearing the redo stack (a fresh edit branches history).
    public mutating func record(_ delta: SceneDelta) {
        guard !delta.isEmpty else { return }
        undoStack.append(delta)
        redoStack.removeAll()
    }

    /// Pop the most recent change for undoing; the caller applies its inverse.
    public mutating func popUndo() -> SceneDelta? {
        guard let delta = undoStack.popLast() else { return nil }
        redoStack.append(delta)
        return delta
    }

    /// Pop the most recently undone change for redoing; the caller re-applies it.
    public mutating func popRedo() -> SceneDelta? {
        guard let delta = redoStack.popLast() else { return nil }
        undoStack.append(delta)
        return delta
    }
}

/// Ties a `Scene` to a `History`: capture edits, then undo/redo them. Mutate the
/// scene via `store.scene`, then call `commit()` to snapshot the change.
public struct Store: Sendable {
    public private(set) var scene: Scene
    private var history = History()
    private var snapshot: [ExcalidrawElement]

    public init(scene: Scene) {
        self.scene = scene
        snapshot = scene.elements
    }

    public var canUndo: Bool {
        history.canUndo
    }

    public var canRedo: Bool {
        history.canRedo
    }

    /// Mutate the scene in a closure and capture the change as one undo step.
    public mutating func transaction(_ body: (inout Scene) -> Void) {
        body(&scene)
        commit()
    }

    /// Mutate the working scene without recording history. Call `commit()` once
    /// the interaction settles to capture the net change as a single undo step.
    public mutating func modifyScene(_ body: (inout Scene) -> Void) {
        body(&scene)
    }

    /// Advance the undo baseline to the current scene *without* recording a step
    /// — used after applying a remote collaborative update so it doesn't fold
    /// into the local user's next undo. (parity: TS `Store.rebase`)
    public mutating func rebase() {
        snapshot = scene.elements
    }

    /// Capture any changes made to `scene` since the last commit as one undo step.
    public mutating func commit() {
        let delta = SceneDelta.between(snapshot, scene.elements)
        guard !delta.isEmpty else { return }
        history.record(delta)
        snapshot = scene.elements
    }

    @discardableResult
    public mutating func undo() -> Bool {
        guard let delta = history.popUndo() else { return false }
        scene.apply(delta.inverse())
        snapshot = scene.elements
        return true
    }

    @discardableResult
    public mutating func redo() -> Bool {
        guard let delta = history.popRedo() else { return false }
        scene.apply(delta)
        snapshot = scene.elements
        return true
    }
}
