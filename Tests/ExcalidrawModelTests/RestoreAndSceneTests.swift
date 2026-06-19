import ExcalidrawMath
import XCTest
@testable import ExcalidrawModel

final class RestoreAndSceneTests: XCTestCase {
    private func element(_ id: String, index: String?) -> ExcalidrawElement {
        var base = BaseProperties(id: id)
        base.index = index
        return ExcalidrawElement(base: base, kind: .rectangle)
    }

    func testRestoreAssignsMissingIndices() {
        let file = ExcalidrawFile(elements: [
            element("a", index: nil),
            element("b", index: nil),
            element("c", index: nil)
        ])
        let restored = Restore.restore(file)
        let indices = restored.elements.map(\.base.index)
        XCTAssertFalse(indices.contains(nil))
        // Keys must sort in document order.
        let sorted = indices.compactMap(\.self).sorted()
        XCTAssertEqual(indices.compactMap(\.self), sorted)
    }

    func testRestoreHealsDuplicateIDs() {
        // A scene corrupted before the id-collision fix: two elements share "a".
        let file = ExcalidrawFile(elements: [
            element("a", index: "a0"),
            element("a", index: "a1"),
            element("b", index: "a2")
        ])
        let restored = Restore.restore(file)
        let ids = restored.elements.map(\.base.id)
        XCTAssertEqual(restored.elements.count, 3) // none dropped
        XCTAssertEqual(Set(ids).count, 3) // all ids now unique → all deletable
        XCTAssertEqual(ids.first, "a") // first occurrence keeps its id
    }

    func testRestorePreservesExistingIndices() {
        let file = ExcalidrawFile(elements: [element("a", index: "a0"), element("b", index: nil)])
        let restored = Restore.restore(file)
        XCTAssertEqual(restored.elements[0].base.index, "a0")
        XCTAssertNotNil(restored.elements[1].base.index)
    }

    func testRestoreUpgradesVersionAndType() {
        let file = ExcalidrawFile(type: "x", version: 1, elements: [])
        let restored = Restore.restore(file)
        XCTAssertEqual(restored.type, "excalidraw")
        XCTAssertEqual(restored.version, 2)
    }

    func testSceneLookupAddRemove() {
        var scene = Scene(elements: [element("a", index: "a0")])
        XCTAssertNotNil(scene.element(id: "a"))
        scene.add(element("b", index: "a1"))
        XCTAssertEqual(scene.visibleElements.count, 2)

        XCTAssertTrue(scene.remove(id: "a"))
        XCTAssertEqual(scene.visibleElements.count, 1)
        XCTAssertEqual(scene.element(id: "a")?.base.isDeleted, true)
        XCTAssertFalse(scene.remove(id: "missing"))
    }

    func testMutateBumpsVersionAndNonce() {
        var scene = Scene(elements: [element("a", index: "a0")])
        scene.mutate(id: "a", versionNonce: 999) { $0.base.opacity = 50 }
        let updated = scene.element(id: "a")
        XCTAssertEqual(updated?.base.opacity, 50)
        XCTAssertEqual(updated?.base.version, 2)
        XCTAssertEqual(updated?.base.versionNonce, 999)
    }

    func testAppStateAccessorsAndPassthrough() throws {
        let json = Data(##"{"viewBackgroundColor":"#fff","gridModeEnabled":true,"unknownKey":[1,2]}"##.utf8)
        let appState = try JSONDecoder().decode(AppState.self, from: json)
        XCTAssertEqual(appState.viewBackgroundColor, "#fff")
        XCTAssertEqual(appState.gridModeEnabled, true)
        // Unknown keys survive a round trip.
        let reencoded = try JSONEncoder().encode(appState)
        let again = try JSONDecoder().decode(AppState.self, from: reencoded)
        XCTAssertEqual(again.raw["unknownKey"], .array([.number(1), .number(2)]))
    }
}
