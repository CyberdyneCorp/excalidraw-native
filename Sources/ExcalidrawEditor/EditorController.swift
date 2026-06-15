import ExcalidrawGeometry
import ExcalidrawMath
import ExcalidrawModel
import Foundation

/// The editing state machine: turns scene-space pointer events into element
/// creation, selection, move, resize, and rotation, with undo/redo. Pure Swift
/// (no UIKit) so it is fully unit-testable; the UI layer feeds it `PointerEvent`s
/// and renders `scene` plus the overlay. Mirrors the pointer flow of `App.tsx`.
public final class EditorController {
    public private(set) var store: Store
    public var activeTool: Tool = .selection
    public var toolLocked = false
    public var currentItem = CurrentItemProperties()
    public var zoom: Double = 1
    public private(set) var selectedIDs: Set<String> = []
    /// Live box-selection rectangle, for the overlay (nil when not box-selecting).
    public private(set) var selectionRect: BoundingBox?

    private var nextID: () -> String
    private var nextSeed: () -> Int

    private enum Interaction {
        case idle
        case creating(id: String, origin: Point, moved: Bool)
        case moving(origin: Point, originals: [String: ExcalidrawElement])
        case boxSelecting(origin: Point)
        case resizing(handle: TransformHandle, bounds: BoundingBox, originals: [String: ExcalidrawElement])
        case rotating(center: Point, originals: [String: ExcalidrawElement])
    }

    private var interaction: Interaction = .idle

    public init(
        scene: Scene = Scene(),
        idProvider: (() -> String)? = nil,
        seedProvider: (() -> Int)? = nil
    ) {
        store = Store(scene: scene)
        var idCounter = 0
        var seedCounter = 1
        nextID = idProvider ?? { idCounter += 1; return "el-\(idCounter)" }
        nextSeed = seedProvider ?? { seedCounter += 1; return seedCounter * 100_001 }
    }

    public var scene: Scene { store.scene }
    public var canUndo: Bool { store.canUndo }
    public var canRedo: Bool { store.canRedo }

    public var selectedElements: [ExcalidrawElement] {
        scene.visibleElements.filter { selectedIDs.contains($0.id) }
    }

    /// Bounding box of the current selection (nil if empty).
    public var selectionBounds: BoundingBox? {
        ElementGeometry.commonBounds(selectedElements)
    }

    /// Handle positions for the current selection, shown by the overlay when the
    /// selection tool is active.
    public func transformHandles() -> [TransformHandle: Point] {
        guard activeTool == .selection, let bounds = selectionBounds else { return [:] }
        return Transform.handlePositions(for: bounds, rotationOffset: rotationOffset)
    }

    // MARK: Pointer handling

    public func pointerDown(_ event: PointerEvent) {
        selectionRect = nil
        if let kind = activeTool.elementKind {
            beginCreating(kind: kind, at: event.scenePoint)
            return
        }
        beginSelectionInteraction(event)
    }

    public func pointerMove(_ event: PointerEvent) {
        switch interaction {
        case let .creating(id, origin, _):
            updateCreating(id: id, origin: origin, to: event.scenePoint)
            interaction = .creating(id: id, origin: origin, moved: true)
        case let .moving(origin, originals):
            let dx = event.scenePoint.x - origin.x
            let dy = event.scenePoint.y - origin.y
            store.modifyScene { scene in
                for (id, original) in originals {
                    scene.replace(Transform.translate(original, dx: dx, dy: dy))
                    _ = id
                }
            }
        case let .boxSelecting(origin):
            selectionRect = Self.bbox(origin, event.scenePoint)
        case let .resizing(handle, bounds, originals):
            let newBounds = Transform.resize(
                bounds, handle: handle, to: event.scenePoint,
                keepAspect: event.shift, fromCenter: event.alt
            )
            store.modifyScene { scene in
                for (_, original) in originals {
                    scene.replace(Transform.scale(original, from: bounds, to: newBounds))
                }
            }
        case let .rotating(center, originals):
            let angle = Transform.rotationAngle(center: center, pointer: event.scenePoint, snap: event.shift)
            store.modifyScene { scene in
                for (_, original) in originals {
                    var e = original
                    e.base.angle = angle
                    scene.replace(e)
                }
            }
        case .idle:
            break
        }
    }

    public func pointerUp(_ event: PointerEvent) {
        switch interaction {
        case let .creating(id, _, moved):
            finishCreating(id: id, moved: moved)
        case .moving, .resizing, .rotating:
            store.commit()
        case let .boxSelecting(origin):
            selectWithin(Self.bbox(origin, event.scenePoint), additive: event.toggleSelection)
            selectionRect = nil
        case .idle:
            break
        }
        interaction = .idle
    }

    // MARK: Commands

    public func setTool(_ tool: Tool) { activeTool = tool }
    public func selectAll() { selectedIDs = Set(scene.visibleElements.map(\.id)) }
    public func clearSelection() { selectedIDs = [] }

    public func deleteSelected() {
        guard !selectedIDs.isEmpty else { return }
        store.transaction { scene in
            for id in selectedIDs { scene.remove(id: id) }
        }
        selectedIDs = []
    }

    /// Apply a change to every selected element as one undo step (e.g. a style
    /// edit from the properties panel).
    public func updateSelected(_ change: (inout ExcalidrawElement) -> Void) {
        guard !selectedIDs.isEmpty else { return }
        store.transaction { scene in
            for id in selectedIDs {
                guard var element = scene.element(id: id) else { continue }
                change(&element)
                scene.replace(element)
            }
        }
    }

    @discardableResult public func undo() -> Bool {
        let ok = store.undo()
        pruneSelection()
        return ok
    }

    @discardableResult public func redo() -> Bool {
        let ok = store.redo()
        pruneSelection()
        return ok
    }

    // MARK: Interaction helpers

    private func beginCreating(kind: ElementKind, at origin: Point) {
        let base = currentItem.makeBase(id: nextID(), seed: nextSeed(), x: origin.x, y: origin.y)
        let element: ExcalidrawElement
        if case .line = kind {
            element = ExcalidrawElement(base: base, kind: .line(LinearProperties(points: [Point(0, 0), Point(0, 0)])))
        } else {
            element = ExcalidrawElement(base: base, kind: kind)
        }
        store.modifyScene { $0.add(element) }
        selectedIDs = [element.id]
        interaction = .creating(id: element.id, origin: origin, moved: false)
    }

    private func updateCreating(id: String, origin: Point, to point: Point) {
        guard var element = scene.element(id: id) else { return }
        if case var .line(props) = element.kind {
            element.base.x = origin.x
            element.base.y = origin.y
            element.base.width = abs(point.x - origin.x)
            element.base.height = abs(point.y - origin.y)
            props.points = [Point(0, 0), Point(point.x - origin.x, point.y - origin.y)]
            element.kind = .line(props)
        } else {
            element.base.x = Swift.min(origin.x, point.x)
            element.base.y = Swift.min(origin.y, point.y)
            element.base.width = abs(point.x - origin.x)
            element.base.height = abs(point.y - origin.y)
        }
        store.modifyScene { $0.replace(element) }
    }

    private func finishCreating(id: String, moved: Bool) {
        let element = scene.element(id: id)
        let tiny = (element?.base.width ?? 0) < Transform.minSize && (element?.base.height ?? 0) < Transform.minSize
        if !moved || tiny {
            // A click without a drag creates nothing.
            store.modifyScene { scene in
                scene = Scene(
                    elements: scene.elements.filter { $0.id != id },
                    appState: scene.appState, files: scene.files
                )
            }
            selectedIDs = []
        } else {
            store.commit()
            if !toolLocked { activeTool = .selection }
        }
    }

    private func beginSelectionInteraction(_ event: PointerEvent) {
        let point = event.scenePoint
        // Handles take priority when something is selected.
        if let bounds = selectionBounds {
            for (handle, position) in Transform.handlePositions(for: bounds, rotationOffset: rotationOffset)
                where position.distance(to: point) <= handleHitRadius(event.type) {
                let originals = snapshotSelected()
                interaction = handle == .rotation
                    ? .rotating(center: Point((bounds.minX + bounds.maxX) / 2, (bounds.minY + bounds.maxY) / 2),
                                originals: originals)
                    : .resizing(handle: handle, bounds: bounds, originals: originals)
                return
            }
        }

        if let hit = topElement(at: point, type: event.type) {
            if event.toggleSelection {
                if selectedIDs.contains(hit) { selectedIDs.remove(hit) } else { selectedIDs.insert(hit) }
            } else if !selectedIDs.contains(hit) {
                selectedIDs = [hit]
            }
            interaction = .moving(origin: point, originals: snapshotSelected())
        } else {
            if !event.toggleSelection { selectedIDs = [] }
            interaction = .boxSelecting(origin: point)
            selectionRect = BoundingBox(minX: point.x, minY: point.y, maxX: point.x, maxY: point.y)
        }
    }

    private func snapshotSelected() -> [String: ExcalidrawElement] {
        Dictionary(selectedElements.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private func topElement(at point: Point, type: PointerType) -> String? {
        let threshold = handleHitRadius(type)
        for element in scene.visibleElements.reversed()
            where !element.base.locked && HitTest.hit(element, at: point, threshold: threshold) {
            return element.id
        }
        return nil
    }

    private func selectWithin(_ rect: BoundingBox, additive: Bool) {
        let within = scene.visibleElements.filter { element in
            let b = ElementGeometry.bounds(element)
            return b.minX >= rect.minX && b.maxX <= rect.maxX && b.minY >= rect.minY && b.maxY <= rect.maxY
        }.map(\.id)
        if additive { selectedIDs.formUnion(within) } else { selectedIDs = Set(within) }
    }

    private func pruneSelection() {
        let live = Set(scene.visibleElements.map(\.id))
        selectedIDs.formIntersection(live)
    }

    private func handleHitRadius(_ type: PointerType) -> Double {
        let px: Double
        switch type {
        case .touch: px = 28
        case .pen: px = 16
        case .mouse: px = 10
        }
        return px / zoom
    }

    private var rotationOffset: Double { 30 / zoom }

    /// Normalized bounding box of two corner points.
    private static func bbox(_ a: Point, _ b: Point) -> BoundingBox {
        BoundingBox(
            minX: Swift.min(a.x, b.x), minY: Swift.min(a.y, b.y),
            maxX: Swift.max(a.x, b.x), maxY: Swift.max(a.y, b.y)
        )
    }
}
