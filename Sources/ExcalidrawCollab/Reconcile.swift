import ExcalidrawModel

/// Element reconciliation — the deterministic, symmetric last-writer-wins rule
/// shared bit-for-bit with the TypeScript `@xs/protocol` `reconcile`: higher
/// `version` wins; ties break on the lower `versionNonce`. Both clients converge
/// on the same element with no central authority or CRDT.
public enum Reconcile {
    /// Whether `remote` should replace the same-id `local` element.
    public static func preferRemote(local: ExcalidrawElement, remote: ExcalidrawElement) -> Bool {
        if remote.base.version != local.base.version {
            return remote.base.version > local.base.version
        }
        return remote.base.versionNonce < local.base.versionNonce
    }

    /// The winning element of a same-id pair (the local one on an exact tie).
    public static func reconcile(local: ExcalidrawElement, remote: ExcalidrawElement) -> ExcalidrawElement {
        preferRemote(local: local, remote: remote) ? remote : local
    }

    /// Merge a remote batch into `local` by id, preserving local order and
    /// appending remote-only elements.
    public static func reconcileElements(
        local: [ExcalidrawElement], remote: [ExcalidrawElement]
    ) -> [ExcalidrawElement] {
        var remoteById: [String: ExcalidrawElement] = [:]
        for element in remote {
            remoteById[element.id] = element
        }

        var seen = Set<String>()
        var merged: [ExcalidrawElement] = []
        for localElement in local {
            if let remoteElement = remoteById[localElement.id] {
                merged.append(reconcile(local: localElement, remote: remoteElement))
            } else {
                merged.append(localElement)
            }
            seen.insert(localElement.id)
        }
        for remoteElement in remote where !seen.contains(remoteElement.id) {
            merged.append(remoteElement)
            seen.insert(remoteElement.id)
        }
        return merged
    }

    /// Only the elements that changed (new id, or the remote version won).
    public static func changedByReconcile(
        local: [ExcalidrawElement], remote: [ExcalidrawElement]
    ) -> [ExcalidrawElement] {
        var localById: [String: ExcalidrawElement] = [:]
        for element in local {
            localById[element.id] = element
        }
        return remote.filter { remoteElement in
            guard let localElement = localById[remoteElement.id] else { return true }
            return preferRemote(local: localElement, remote: remoteElement)
        }
    }
}
