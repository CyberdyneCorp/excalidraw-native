import ExcalidrawGeometry
import ExcalidrawMath
import ExcalidrawModel
import XCTest
@testable import ExcalidrawEditor

final class EditorControllerTests: XCTestCase {
    private func makeEditor(_ scene: Scene = Scene()) -> EditorController {
        var idCount = 0
        var seedCount = 0
        return EditorController(
            scene: scene,
            idProvider: { idCount += 1; return "e\(idCount)" },
            seedProvider: { seedCount += 1; return seedCount }
        )
    }

    private func rect(
        _ id: String, x: Double, y: Double, w: Double, h: Double, bg: String = "#ff0000"
    ) -> ExcalidrawElement {
        var b = BaseProperties(id: id); b.x = x; b.y = y; b.width = w; b.height = h; b.backgroundColor = bg
        return ExcalidrawElement(base: b, kind: .rectangle)
    }

    private func drag(_ ec: EditorController, from: Point, to: Point, type: PointerType = .mouse) {
        ec.pointerDown(PointerEvent(scenePoint: from, phase: .down, type: type))
        ec.pointerMove(PointerEvent(scenePoint: to, phase: .move, type: type))
        ec.pointerUp(PointerEvent(scenePoint: to, phase: .up, type: type))
    }

    func testCreateRectangleByDrag() {
        let ec = makeEditor()
        ec.setTool(.rectangle)
        drag(ec, from: Point(10, 10), to: Point(60, 40))

        XCTAssertEqual(ec.scene.visibleElements.count, 1)
        let e = ec.scene.visibleElements[0]
        XCTAssertEqual(e.base.x, 10)
        XCTAssertEqual(e.base.width, 50)
        XCTAssertEqual(e.base.height, 30)
        XCTAssertTrue(ec.selectedIDs.contains(e.id))
        XCTAssertEqual(ec.activeTool, .selection) // tool reverts after creation
    }

    func testCreateLineByDrag() {
        let ec = makeEditor()
        ec.setTool(.line)
        drag(ec, from: Point(0, 0), to: Point(40, 20))
        guard case let .line(props) = ec.scene.visibleElements.first?.kind else { return XCTFail("line") }
        XCTAssertEqual(props.points.last, Point(40, 20))
    }

    func testClickWithoutDragCreatesNothing() {
        let ec = makeEditor()
        ec.setTool(.rectangle)
        ec.pointerDown(PointerEvent(scenePoint: Point(10, 10), phase: .down))
        ec.pointerUp(PointerEvent(scenePoint: Point(10, 10), phase: .up))
        XCTAssertTrue(ec.scene.visibleElements.isEmpty)
    }

    func testSelectAndMoveThenUndo() {
        let ec = makeEditor(Scene(elements: [rect("r", x: 0, y: 0, w: 100, h: 100)]))
        drag(ec, from: Point(50, 50), to: Point(70, 60)) // select + move by (20,10)
        XCTAssertEqual(ec.scene.element(id: "r")?.base.x, 20)
        XCTAssertEqual(ec.scene.element(id: "r")?.base.y, 10)
        XCTAssertTrue(ec.undo())
        XCTAssertEqual(ec.scene.element(id: "r")?.base.x, 0)
    }

    func testBoxSelectContainedElements() {
        let scene = Scene(elements: [
            rect("a", x: 10, y: 10, w: 20, h: 20),
            rect("b", x: 200, y: 200, w: 20, h: 20),
        ])
        let ec = makeEditor(scene)
        drag(ec, from: Point(0, 0), to: Point(100, 100)) // encloses only "a"
        XCTAssertEqual(ec.selectedIDs, ["a"])
    }

    func testResizeViaHandleThenUndo() {
        let ec = makeEditor(Scene(elements: [rect("r", x: 0, y: 0, w: 100, h: 100)]))
        drag(ec, from: Point(50, 50), to: Point(50, 50)) // select
        XCTAssertEqual(ec.selectedIDs, ["r"])
        // Drag the bottom-right handle outward.
        drag(ec, from: Point(100, 100), to: Point(160, 140))
        XCTAssertEqual(ec.scene.element(id: "r")?.base.width, 160)
        XCTAssertEqual(ec.scene.element(id: "r")?.base.height, 140)
        XCTAssertTrue(ec.undo())
        XCTAssertEqual(ec.scene.element(id: "r")?.base.width, 100)
    }

    func testRotateViaHandle() {
        let ec = makeEditor(Scene(elements: [rect("r", x: 0, y: 0, w: 100, h: 100)]))
        drag(ec, from: Point(50, 50), to: Point(50, 50)) // select
        // Rotation handle at (50, -30); drag it to the right -> ~90°.
        ec.pointerDown(PointerEvent(scenePoint: Point(50, -30), phase: .down))
        ec.pointerMove(PointerEvent(scenePoint: Point(150, 50), phase: .move))
        ec.pointerUp(PointerEvent(scenePoint: Point(150, 50), phase: .up))
        XCTAssertEqual(ec.scene.element(id: "r")?.base.angle ?? 0, .pi / 2, accuracy: 0.2)
    }

    func testToggleMultiSelect() {
        let scene = Scene(elements: [
            rect("a", x: 0, y: 0, w: 40, h: 40),
            rect("b", x: 100, y: 0, w: 40, h: 40),
        ])
        let ec = makeEditor(scene)
        drag(ec, from: Point(20, 20), to: Point(20, 20)) // select a
        ec.pointerDown(PointerEvent(scenePoint: Point(120, 20), phase: .down, toggleSelection: true))
        ec.pointerUp(PointerEvent(scenePoint: Point(120, 20), phase: .up, toggleSelection: true))
        XCTAssertEqual(ec.selectedIDs, ["a", "b"])
    }

    func testDeleteSelectedAndUndo() {
        let ec = makeEditor(Scene(elements: [rect("r", x: 0, y: 0, w: 50, h: 50)]))
        ec.selectAll()
        ec.deleteSelected()
        XCTAssertTrue(ec.scene.visibleElements.isEmpty)
        XCTAssertTrue(ec.undo())
        XCTAssertEqual(ec.scene.visibleElements.count, 1)
    }

    func testLockedElementNotSelectable() {
        var locked = rect("r", x: 0, y: 0, w: 100, h: 100)
        locked.base.locked = true
        let ec = makeEditor(Scene(elements: [locked]))
        drag(ec, from: Point(50, 50), to: Point(50, 50))
        XCTAssertTrue(ec.selectedIDs.isEmpty)
    }

    func testTransformHandlesPresence() {
        let ec = makeEditor(Scene(elements: [rect("r", x: 0, y: 0, w: 50, h: 50)]))
        XCTAssertTrue(ec.transformHandles().isEmpty) // nothing selected
        drag(ec, from: Point(25, 25), to: Point(25, 25)) // select
        XCTAssertEqual(ec.transformHandles().count, 9)
        ec.setTool(.rectangle)
        XCTAssertTrue(ec.transformHandles().isEmpty) // not the selection tool
    }

    func testClearSelection() {
        let ec = makeEditor(Scene(elements: [rect("r", x: 0, y: 0, w: 50, h: 50)]))
        ec.selectAll()
        XCTAssertFalse(ec.selectedIDs.isEmpty)
        ec.clearSelection()
        XCTAssertTrue(ec.selectedIDs.isEmpty)
    }

    func testToolLockedKeepsToolAfterCreate() {
        let ec = makeEditor()
        ec.setTool(.rectangle)
        ec.toolLocked = true
        drag(ec, from: Point(0, 0), to: Point(30, 30))
        XCTAssertEqual(ec.activeTool, .rectangle) // stays on the tool
    }

    func testResizeFromCenter() {
        let ec = makeEditor(Scene(elements: [rect("r", x: 0, y: 0, w: 100, h: 100)]))
        drag(ec, from: Point(50, 50), to: Point(50, 50)) // select
        ec.pointerDown(PointerEvent(scenePoint: Point(100, 100), phase: .down))
        ec.pointerMove(PointerEvent(scenePoint: Point(120, 120), phase: .move, alt: true))
        ec.pointerUp(PointerEvent(scenePoint: Point(120, 120), phase: .up, alt: true))
        // From-centre resize grows symmetrically: origin moves negative.
        XCTAssertLessThan(ec.scene.element(id: "r")?.base.x ?? 0, 0)
    }

    func testFreedrawAccumulatesPointsAndPressure() {
        let ec = makeEditor()
        ec.setTool(.freedraw)
        ec.pointerDown(PointerEvent(scenePoint: Point(0, 0), phase: .down, type: .pen, pressure: 0.3))
        ec.pointerMove(PointerEvent(scenePoint: Point(10, 5), phase: .move, type: .pen, pressure: 0.6))
        ec.pointerMove(PointerEvent(scenePoint: Point(20, 0), phase: .move, type: .pen, pressure: 0.9))
        ec.pointerUp(PointerEvent(scenePoint: Point(20, 0), phase: .up, type: .pen, pressure: 0.9))

        guard case let .freedraw(props) = ec.scene.visibleElements.first?.kind else { return XCTFail("freedraw") }
        XCTAssertEqual(props.points, [Point(0, 0), Point(10, 5), Point(20, 0)])
        XCTAssertEqual(props.pressures, [0.3, 0.6, 0.9])
        XCTAssertEqual(ec.activeTool, .selection)
    }

    func testArrowGetsDefaultEndArrowhead() {
        let ec = makeEditor()
        ec.setTool(.arrow)
        drag(ec, from: Point(0, 0), to: Point(80, 20))
        guard case let .arrow(props) = ec.scene.visibleElements.first?.kind else { return XCTFail("arrow") }
        XCTAssertEqual(props.endArrowhead, .arrow)
        XCTAssertEqual(props.points.last, Point(80, 20))
    }

    func testEraserDeletesAndUndo() {
        let ec = makeEditor(Scene(elements: [rect("r", x: 0, y: 0, w: 100, h: 100)]))
        ec.setTool(.eraser)
        ec.pointerDown(PointerEvent(scenePoint: Point(50, 50), phase: .down))
        ec.pointerUp(PointerEvent(scenePoint: Point(50, 50), phase: .up))
        XCTAssertTrue(ec.scene.visibleElements.isEmpty)
        XCTAssertTrue(ec.undo())
        XCTAssertEqual(ec.scene.visibleElements.count, 1)
    }

    func testHandToolDoesNotCreateOrSelect() {
        let ec = makeEditor(Scene(elements: [rect("r", x: 0, y: 0, w: 100, h: 100)]))
        ec.setTool(.hand)
        drag(ec, from: Point(50, 50), to: Point(80, 80))
        XCTAssertEqual(ec.scene.visibleElements.count, 1) // unchanged
        XCTAssertTrue(ec.selectedIDs.isEmpty)
    }

    func testRedoAfterUndo() {
        let ec = makeEditor()
        ec.setTool(.ellipse)
        drag(ec, from: Point(0, 0), to: Point(40, 40))
        XCTAssertEqual(ec.scene.visibleElements.count, 1)
        XCTAssertTrue(ec.undo())
        XCTAssertEqual(ec.scene.visibleElements.count, 0)
        XCTAssertTrue(ec.redo())
        XCTAssertEqual(ec.scene.visibleElements.count, 1)
    }
}
