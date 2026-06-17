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
        for index in elements.indices {
            elements[index].base.x += point.x - minX
            elements[index].base.y += point.y - minY
        }
        store.transaction { scene in
            for element in elements {
                scene.add(element)
            }
        }
        selectedIDs = Set(elements.map(\.id))
        return true
    }
}
