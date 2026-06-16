import ExcalidrawModel
import ExcalidrawRender

/// Memoizes the tessellated GPU vertices per element so steady-state frames skip
/// re-tessellation (the dominant per-frame cost — ear clipping, stroke quads,
/// trig for round joins). Mirrors `ShapeCache`: keyed by element identity and
/// invalidated whenever the element value or theme changes, since live drag /
/// resize mutate geometry via `Scene.replace` without bumping `version`.
///
/// Vertices are stored in scene coordinates with color baked in, so they stay
/// valid across pan/zoom (only the per-frame clip transform changes); a moved or
/// recolored element misses the cache and is rebuilt.
public final class GeometryCache {
    private struct Entry {
        var element: ExcalidrawElement
        var theme: Theme
        var vertices: [Float]
    }

    private var entries: [String: Entry] = [:]

    public init() {}

    /// Cached vertices for `element` at `theme`, or `build()` recomputed and
    /// cached when the element/theme differs (or was never cached).
    func vertices(for element: ExcalidrawElement, theme: Theme, build: () -> [Float]) -> [Float] {
        if let entry = entries[element.id], entry.element == element, entry.theme == theme {
            return entry.vertices
        }
        let vertices = build()
        entries[element.id] = Entry(element: element, theme: theme, vertices: vertices)
        return vertices
    }

    public func invalidate(id: String) {
        entries[id] = nil
    }

    public func removeAll() {
        entries.removeAll()
    }

    var count: Int {
        entries.count
    }
}
