import ExcalidrawModel
import Foundation
import RoughKit

/// Memoizes generated `Drawable`s per element, invalidating when the element's
/// version changes. Mirrors upstream `ShapeCache` (a `WeakMap` keyed by element
/// with a version guard); here it is an explicit dictionary suitable for value
/// semantics.
public final class ShapeCache {
    private struct Entry {
        var version: Int
        var versionNonce: Int
        var drawable: Drawable?
    }

    private var entries: [String: Entry] = [:]

    public init() {}

    /// Return the cached drawable for `element`, regenerating if its version
    /// changed (or it was never cached).
    public func drawable(for element: ExcalidrawElement) -> Drawable? {
        let id = element.id
        if let entry = entries[id],
           entry.version == element.base.version,
           entry.versionNonce == element.base.versionNonce {
            return entry.drawable
        }
        let drawable = ElementDrawable.drawable(for: element)
        entries[id] = Entry(
            version: element.base.version,
            versionNonce: element.base.versionNonce,
            drawable: drawable
        )
        return drawable
    }

    public func invalidate(id: String) {
        entries[id] = nil
    }

    public func removeAll() {
        entries.removeAll()
    }

    var count: Int { entries.count }
}
