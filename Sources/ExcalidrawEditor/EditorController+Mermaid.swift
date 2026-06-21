import ExcalidrawMath
import ExcalidrawModel

/// Insert a Mermaid flowchart as Excalidraw elements.
public extension EditorController {
    /// Parse `text` as a Mermaid flowchart and insert the resulting shapes,
    /// labels and arrows with their top-left at `point`, selecting them. Returns
    /// whether the text parsed.
    @discardableResult
    func insertMermaid(_ text: String, at point: Point) -> Bool {
        guard var elements = MermaidParser.parse(text, seed: nextSeed()), !elements.isEmpty else { return false }
        let minX = elements.map(\.base.x).min() ?? 0
        let minY = elements.map(\.base.y).min() ?? 0
        // The parser assigns deterministic ids ("mermaid-A", "mermaid-edge-0")
        // identical on every device and every insert. Under collab those collide
        // in the element-LWW reconcile, so a mermaid diagram never syncs to peers.
        // Re-id the whole batch through `nextID()` (peer-prefixed + unique, like
        // every other insert) and remap each intra-batch reference — the bound
        // text, the text's container, and the arrow start/end bindings.
        var idMap: [String: String] = [:]
        for element in elements { idMap[element.id] = nextID() }
        for index in elements.indices {
            elements[index].base.x += point.x - minX
            elements[index].base.y += point.y - minY
            remapMermaidIDs(&elements[index], using: idMap)
        }
        store.transaction { scene in
            for element in elements {
                scene.add(element)
            }
        }
        selectedIDs = Set(elements.map(\.id))
        return true
    }

    /// Rewrite an element's own id and every id it references using `map`
    /// (ids absent from the map are left unchanged).
    private func remapMermaidIDs(_ element: inout ExcalidrawElement, using map: [String: String]) {
        if let newID = map[element.base.id] { element.base.id = newID }
        if let bound = element.base.boundElements {
            element.base.boundElements = bound.map { BoundElement(id: map[$0.id] ?? $0.id, type: $0.type) }
        }
        switch element.kind {
        case .text(var props):
            if let container = props.containerId, let mapped = map[container] { props.containerId = mapped }
            element.kind = .text(props)
        case .arrow(var props):
            if let start = props.startBinding?.elementId, let mapped = map[start] {
                props.startBinding?.elementId = mapped
            }
            if let end = props.endBinding?.elementId, let mapped = map[end] {
                props.endBinding?.elementId = mapped
            }
            element.kind = .arrow(props)
        default:
            break
        }
    }
}
