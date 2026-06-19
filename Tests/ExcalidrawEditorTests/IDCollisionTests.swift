import ExcalidrawMath
import ExcalidrawModel
import XCTest
@testable import ExcalidrawEditor

final class IDCollisionTests: XCTestCase {
    private func rect(_ id: String, _ x: Double = 0) -> ExcalidrawElement {
        var base = BaseProperties(id: id)
        base.x = x
        base.y = 0
        base.width = 40
        base.height = 40
        return ExcalidrawElement(base: base, kind: .rectangle)
    }

    func testFreshDrawDoesNotReuseLoadedID() {
        // Default el-N id generator + a scene pre-loaded with el-1/el-2 (as if a
        // document / autosave / the bundled sample was opened).
        let ec = EditorController(scene: Scene(elements: [rect("el-1"), rect("el-2", 80)]))
        ec.setTool(.rectangle)
        ec.pointerDown(PointerEvent(scenePoint: Point(0, 200), phase: .down))
        ec.pointerMove(PointerEvent(scenePoint: Point(50, 250), phase: .move))
        ec.pointerUp(PointerEvent(scenePoint: Point(50, 250), phase: .up))

        let ids = ec.scene.visibleElements.map(\.id)
        // Regression: the counter restarted at el-1 and collided, so the new shape
        // shared id "el-1" — making move leave a phantom copy and delete remove
        // only one of the twins.
        XCTAssertEqual(Set(ids).count, ids.count) // all ids unique
    }

    func testSceneAddDeduplicatesByID() {
        var scene = Scene(elements: [rect("a")])
        scene.add(rect("a", 999)) // same id, different position
        XCTAssertEqual(scene.elements.count(where: { $0.id == "a" }), 1)
    }
}
