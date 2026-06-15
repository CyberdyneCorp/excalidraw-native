import CoreGraphics
import ExcalidrawEditor
import ExcalidrawModel
import ExcalidrawRender
import XCTest
@testable import ExcalidrawUI

@MainActor
final class EditorModelTests: XCTestCase {
    private func draw(_ m: EditorModel, from: CGPoint, to: CGPoint) {
        m.pointer(.down, at: from)
        m.pointer(.move, at: to)
        m.pointer(.up, at: to)
    }

    func testForwardsPointerAndCreatesElement() {
        let m = EditorModel()
        m.select(tool: .rectangle)
        let before = m.revision
        draw(m, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 60, y: 40))
        XCTAssertEqual(m.controller.scene.visibleElements.count, 1)
        XCTAssertGreaterThan(m.revision, before)
        XCTAssertEqual(m.activeTool, .selection) // reverts after creation
    }

    func testViewToSceneConversionWithViewport() {
        let m = EditorModel(viewport: Viewport(scrollX: 0, scrollY: 0, zoom: 2))
        m.select(tool: .rectangle)
        draw(m, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 120))
        // View (20,20) at zoom 2 → scene (10,10).
        XCTAssertEqual(m.controller.scene.visibleElements.first?.base.x, 10)
    }

    func testStrokeColorAndWidthApplyToSelection() {
        let m = EditorModel()
        m.select(tool: .rectangle)
        draw(m, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 50, y: 50))
        m.setStrokeColor("#e03131")
        m.setStrokeWidth(6)
        let element = m.controller.selectedElements.first
        XCTAssertEqual(element?.base.strokeColor, "#e03131")
        XCTAssertEqual(element?.base.strokeWidth, 6)
        XCTAssertEqual(m.controller.currentItem.strokeColor, "#e03131")
    }

    func testUndoRedoDelete() {
        let m = EditorModel()
        m.select(tool: .ellipse)
        draw(m, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 40, y: 40))
        m.undo()
        XCTAssertEqual(m.controller.scene.visibleElements.count, 0)
        m.redo()
        XCTAssertEqual(m.controller.scene.visibleElements.count, 1)
        m.controller.selectAll()
        m.deleteSelected()
        XCTAssertEqual(m.controller.scene.visibleElements.count, 0)
    }

    func testPanZoomUpdatesViewport() {
        let m = EditorModel(viewport: Viewport(scrollX: 0, scrollY: 0, zoom: 1))
        m.panZoom(translation: CGSize(width: 10, height: 20), scale: 2)
        XCTAssertEqual(m.viewport.zoom, 2)
        XCTAssertEqual(m.controller.zoom, 2)
        XCTAssertEqual(m.viewport.scrollX, 5) // 10 / zoom(2)
    }

    func testExport() {
        let m = EditorModel()
        XCTAssertNil(m.exportPNG()) // empty scene
        m.select(tool: .rectangle)
        draw(m, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 80, y: 50))
        XCTAssertNotNil(m.exportPNG())
    }
}
