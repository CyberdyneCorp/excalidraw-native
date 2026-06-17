import ExcalidrawModel
import XCTest
@testable import ExcalidrawCollab

/// Mirrors the TypeScript `reconcile.test.ts` so both clients resolve conflicts
/// identically.
final class ReconcileTests: XCTestCase {
    private func element(_ id: String, version: Int, versionNonce: Int = 0) -> ExcalidrawElement {
        var base = BaseProperties(id: id)
        base.version = version
        base.versionNonce = versionNonce
        return ExcalidrawElement(base: base, kind: .rectangle)
    }

    func testHigherVersionWins() {
        let local = element("a", version: 1, versionNonce: 100)
        let remote = element("a", version: 2, versionNonce: 5)
        XCTAssertEqual(Reconcile.reconcile(local: local, remote: remote).base.version, 2)
        XCTAssertEqual(Reconcile.reconcile(local: remote, remote: local).base.version, 2)
    }

    func testKeepsLocalWhenNewer() {
        let local = element("a", version: 3, versionNonce: 100)
        let remote = element("a", version: 2, versionNonce: 5)
        XCTAssertEqual(Reconcile.reconcile(local: local, remote: remote).base.version, 3)
    }

    func testVersionTieBreaksOnLowerNonce() {
        let local = element("a", version: 4, versionNonce: 200)
        let remote = element("a", version: 4, versionNonce: 50)
        XCTAssertTrue(Reconcile.preferRemote(local: local, remote: remote))
        XCTAssertEqual(Reconcile.reconcile(local: local, remote: remote).base.versionNonce, 50)
    }

    func testSymmetricConvergence() {
        let x = element("a", version: 4, versionNonce: 50)
        let y = element("a", version: 4, versionNonce: 200)
        let peer1 = Reconcile.reconcile(local: x, remote: y)
        let peer2 = Reconcile.reconcile(local: y, remote: x)
        XCTAssertEqual(peer1.base.versionNonce, peer2.base.versionNonce)
        XCTAssertEqual(peer1.base.versionNonce, 50)
    }

    func testReconcileElementsMerges() {
        let local = [element("a", version: 2), element("b", version: 1)]
        let remote = [element("a", version: 3), element("c", version: 1)]
        let merged = Reconcile.reconcileElements(local: local, remote: remote)
        XCTAssertEqual(merged.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(merged.first { $0.id == "a" }?.base.version, 3)
    }

    func testChangedByReconcile() {
        let local = [element("a", version: 2), element("b", version: 5)]
        let remote = [element("a", version: 3), element("b", version: 1), element("c", version: 1)]
        let changed = Reconcile.changedByReconcile(local: local, remote: remote).map(\.id).sorted()
        XCTAssertEqual(changed, ["a", "c"])
    }
}
