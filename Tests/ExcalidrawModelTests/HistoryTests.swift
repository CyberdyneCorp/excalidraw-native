import XCTest
@testable import ExcalidrawModel

final class HistoryTests: XCTestCase {
    private func rect(_ id: String, x: Double = 0) -> ExcalidrawElement {
        var base = BaseProperties(id: id)
        base.x = x
        return ExcalidrawElement(base: base, kind: .rectangle)
    }

    func testDeltaBetweenDetectsChanges() {
        let a = rect("a")
        var aMoved = a
        aMoved.base.x = 50
        let delta = SceneDelta.between([a], [aMoved])
        XCTAssertEqual(delta.changes.count, 1)
        XCTAssertEqual(delta.changes["a"]?.after?.base.x, 50)
    }

    func testDeltaIsEmptyWhenUnchanged() {
        let a = rect("a")
        XCTAssertTrue(SceneDelta.between([a], [a]).isEmpty)
    }

    func testInverseSwapsBeforeAfter() {
        let delta = SceneDelta.between([rect("a", x: 0)], [rect("a", x: 9)])
        let inverse = delta.inverse()
        XCTAssertEqual(inverse.changes["a"]?.after?.base.x, 0)
    }

    func testUndoRedoMove() {
        var store = Store(scene: Scene(elements: [rect("a", x: 0)]))
        store.transaction { $0.mutate(id: "a") { $0.base.x = 100 } }
        XCTAssertEqual(store.scene.element(id: "a")?.base.x, 100)
        XCTAssertTrue(store.canUndo)

        XCTAssertTrue(store.undo())
        XCTAssertEqual(store.scene.element(id: "a")?.base.x, 0)
        XCTAssertTrue(store.canRedo)

        XCTAssertTrue(store.redo())
        XCTAssertEqual(store.scene.element(id: "a")?.base.x, 100)
    }

    func testUndoInsertionRemovesElement() {
        var store = Store(scene: Scene(elements: [rect("a")]))
        store.transaction { $0.add(rect("b", x: 5)) }
        XCTAssertEqual(store.scene.elements.count, 2)
        XCTAssertTrue(store.undo())
        XCTAssertNil(store.scene.element(id: "b"))
        XCTAssertEqual(store.scene.elements.count, 1)
        XCTAssertTrue(store.redo())
        XCTAssertNotNil(store.scene.element(id: "b"))
    }

    func testNewEditClearsRedoStack() {
        var store = Store(scene: Scene(elements: [rect("a", x: 0)]))
        store.transaction { $0.mutate(id: "a") { $0.base.x = 1 } }
        store.undo()
        XCTAssertTrue(store.canRedo)
        store.transaction { $0.mutate(id: "a") { $0.base.x = 2 } }
        XCTAssertFalse(store.canRedo) // branch discarded
    }

    func testEmptyCommitDoesNothing() {
        var store = Store(scene: Scene(elements: [rect("a")]))
        store.commit()
        XCTAssertFalse(store.canUndo)
        XCTAssertFalse(store.undo())
        XCTAssertFalse(store.redo())
    }

    func testApplyPreservesOrder() {
        var scene = Scene(elements: [rect("a"), rect("b"), rect("c")])
        var bMoved = rect("b", x: 99)
        bMoved.base.version = 2
        scene.apply(SceneDelta(changes: ["b": ElementChange(before: rect("b"), after: bMoved)]))
        XCTAssertEqual(scene.elements.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(scene.element(id: "b")?.base.x, 99)
    }

    // Regression: a drag-created/resized shape updated geometry via `replace`
    // (no version bump), so it kept its zero-size creation version and never
    // re-broadcast — peers saw width=0/height=0. commit() must seal it.
    func testCommitBumpsVersionOnLiveReplacedElement() throws {
        var store = Store(scene: Scene(elements: [rect("a")]))
        let v0 = try XCTUnwrap(store.scene.element(id: "a")?.base.version)
        store.modifyScene { scene in
            var e = scene.element(id: "a")!
            e.base.width = 120
            e.base.height = 80
            _ = scene.replace(e)
        }
        XCTAssertEqual(store.scene.element(id: "a")?.base.version, v0) // replace doesn't bump
        store.commit()
        XCTAssertEqual(store.scene.element(id: "a")?.base.width, 120)
        XCTAssertGreaterThan(try XCTUnwrap(store.scene.element(id: "a")?.base.version), v0) // sealed
    }

    func testCommitDoesNotDoubleBumpDiscreteEdit() throws {
        var store = Store(scene: Scene(elements: [rect("a", x: 0)]))
        let v0 = try XCTUnwrap(store.scene.element(id: "a")?.base.version)
        store.transaction { $0.mutate(id: "a") { $0.base.x = 100 } }
        XCTAssertEqual(store.scene.element(id: "a")?.base.version, v0 + 1) // exactly one bump
    }
}
