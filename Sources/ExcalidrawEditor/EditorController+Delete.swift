import ExcalidrawModel

/// Deletion and element-id helpers, split out of `EditorController` to keep the
/// main type body within SwiftLint's `type_body_length`.
extension EditorController {
    /// Highest `<prefix>el-N` number already present in `scene`, so `idCounter`
    /// can be seeded past it. A loaded document / autosave / bundled sample uses
    /// the same `el-N` scheme, so without seeding the counter restarts at el-1
    /// and collides — producing two elements with one id (a phantom copy on
    /// move, un-deletable, oversized selection).
    static func maxElementNumber(in scene: Scene, prefix: String) -> Int {
        let token = "\(prefix)el-"
        var maxN = 0
        for element in scene.elements where element.id.hasPrefix(token) {
            if let n = Int(element.id.dropFirst(token.count)) { maxN = max(maxN, n) }
        }
        return maxN
    }

    /// A selection expanded to include the bound text of every selected
    /// container, so deleting a labeled shape / sticky note / table cell removes
    /// its label too instead of orphaning it on screen.
    func withBoundText(_ ids: Set<String>) -> Set<String> {
        var out = ids
        for id in ids {
            for bound in scene.element(id: id)?.base.boundElements ?? [] where bound.type == .text {
                out.insert(bound.id)
            }
        }
        return out
    }

    /// Strip references to `removed` ids from surviving elements — bound-element
    /// lists and arrow start/end bindings — so nothing points at a deleted element.
    static func dropDanglingRefs(_ scene: inout Scene, removed: Set<String>) {
        for element in scene.visibleElements {
            var next = element
            var changed = false
            if let bound = next.base.boundElements, bound.contains(where: { removed.contains($0.id) }) {
                next.base.boundElements = bound.filter { !removed.contains($0.id) }
                changed = true
            }
            switch next.kind {
            case var .line(props):
                var kindChanged = false
                if let b = props.startBinding,
                   removed.contains(b.elementId) { props.startBinding = nil; kindChanged = true }
                if let b = props.endBinding,
                   removed.contains(b.elementId) { props.endBinding = nil; kindChanged = true }
                if kindChanged { next.kind = .line(props); changed = true }
            case var .arrow(props):
                var kindChanged = false
                if let b = props.startBinding,
                   removed.contains(b.elementId) { props.startBinding = nil; kindChanged = true }
                if let b = props.endBinding,
                   removed.contains(b.elementId) { props.endBinding = nil; kindChanged = true }
                if kindChanged { next.kind = .arrow(props); changed = true }
            default:
                break
            }
            if changed { _ = scene.replace(next) }
        }
    }
}
