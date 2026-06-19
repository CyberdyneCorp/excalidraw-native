import ExcalidrawMath
import ExcalidrawModel
import XCTest
@testable import ExcalidrawEditor

final class EraserTests: XCTestCase {
    /// A horizontal freedraw stroke along y=0 from x=0..100.
    private func stroke() -> ExcalidrawElement {
        var base = BaseProperties(id: "s")
        base.x = 0
        base.y = 0
        base.width = 100
        base.height = 0
        return ExcalidrawElement(
            base: base,
            kind: .freedraw(FreedrawProperties(
                points: [Point(0, 0), Point(50, 0), Point(100, 0)],
                pressures: [],
                simulatePressure: true
            ))
        )
    }

    func testTouchEraserRemovesStrokeAMouseWouldMiss() {
        let ec = EditorController(scene: Scene(elements: [stroke()]))
        ec.setTool(.eraser)
        // 18 units from the stroke: inside the touch radius (28), outside the old
        // hardcoded mouse radius (10). On iPad this is "can't erase" vs. erasing.
        ec.pointerDown(PointerEvent(scenePoint: Point(50, 18), phase: .down, type: .touch))
        XCTAssertEqual(ec.scene.visibleElements.count, 0)
    }

    func testPencilEraserRemovesWithinItsRadius() {
        let ec = EditorController(scene: Scene(elements: [stroke()]))
        ec.setTool(.eraser)
        ec.pointerDown(PointerEvent(scenePoint: Point(50, 14), phase: .down, type: .pen))
        XCTAssertEqual(ec.scene.visibleElements.count, 0)
    }

    func testFarPointLeavesStrokeAlone() {
        let ec = EditorController(scene: Scene(elements: [stroke()]))
        ec.setTool(.eraser)
        ec.pointerDown(PointerEvent(scenePoint: Point(50, 60), phase: .down, type: .touch))
        XCTAssertEqual(ec.scene.visibleElements.count, 1) // 60 > 28, untouched
    }
}
