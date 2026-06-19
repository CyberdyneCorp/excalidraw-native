import Foundation

/// Load-time normalisation, the Swift counterpart to `packages/excalidraw/data/
/// restore.ts`. This is the single entry point all loaded files should pass
/// through. Phase 1 implements the highest-value, safe normalisations; richer
/// migrations (legacy binding v1 → v2, container repair, oversized-arrow
/// clamping) land incrementally and each gets a regression fixture.
public enum Restore {
    public static func restore(_ file: ExcalidrawFile) -> ExcalidrawFile {
        var file = file
        file.type = ExcalidrawSchema.fileType
        if file.version < ExcalidrawSchema.schemaVersion {
            file.version = ExcalidrawSchema.schemaVersion
        }
        file.elements = restoreElements(file.elements)
        return file
    }

    static func restoreElements(_ elements: [ExcalidrawElement]) -> [ExcalidrawElement] {
        var result = dedupeIDs(elements)
        assignMissingIndices(&result)
        return result
    }

    /// Heal duplicate element ids in a loaded document. A scene corrupted before
    /// the id-collision fix can contain two elements sharing one id; the scene
    /// index then maps that id to only one of them, leaving the other
    /// un-selectable and un-deletable. Keep the first occurrence's id and mint a
    /// fresh unique id for each later twin so every element becomes addressable.
    static func dedupeIDs(_ elements: [ExcalidrawElement]) -> [ExcalidrawElement] {
        var used = Set<String>()
        return elements.map { element in
            if !used.contains(element.base.id) {
                used.insert(element.base.id)
                return element
            }
            var n = 2
            var id = "\(element.base.id)-\(n)"
            while used.contains(id) {
                n += 1
                id = "\(element.base.id)-\(n)"
            }
            used.insert(id)
            var copy = element
            copy.base.id = id
            return copy
        }
    }

    /// Ensure every element carries a fractional `index`. Existing indices are
    /// preserved; gaps are filled with monotonically increasing keys derived
    /// from array order.
    ///
    /// NOTE: this is a simplified, lexicographically-monotone generator, not the
    /// full rocicorp fractional-indexing algorithm. It is sufficient for stable
    /// ordering within a document; the complete algorithm (needed for conflict-
    /// free concurrent inserts) is a later increment.
    static func assignMissingIndices(_ elements: inout [ExcalidrawElement]) {
        guard elements.contains(where: { $0.base.index == nil }) else { return }
        for i in elements.indices where elements[i].base.index == nil {
            elements[i].base.index = FractionalIndex.key(forPosition: i)
        }
    }
}

/// Minimal fractional-index key support. Fixed-width keys sort lexicographically
/// in the same order as their numeric position.
enum FractionalIndex {
    static func key(forPosition position: Int) -> String {
        // 7 base-36 digits keep keys ordered for millions of elements.
        let digits = String(position, radix: 36)
        let padded = String(repeating: "0", count: max(0, 7 - digits.count)) + digits
        return "a" + padded
    }
}
