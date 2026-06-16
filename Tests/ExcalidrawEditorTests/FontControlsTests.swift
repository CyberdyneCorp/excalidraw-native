import ExcalidrawMath
import ExcalidrawModel
import XCTest
@testable import ExcalidrawEditor

final class FontControlsTests: XCTestCase {
    private func editor(withText: Bool) -> EditorController {
        var idCount = 0
        let elements: [ExcalidrawElement]
        if withText {
            var base = BaseProperties(id: "t"); base.width = 60; base.height = 25
            let props = TextProperties(fontSize: 20, fontFamily: FontFamily.excalifont, text: "Hi", originalText: "Hi")
            elements = [ExcalidrawElement(base: base, kind: .text(props))]
        } else {
            elements = []
        }
        let ec = EditorController(scene: Scene(elements: elements), idProvider: { idCount += 1; return "n\(idCount)" })
        if withText { ec.selectAll() }
        return ec
    }

    func testCreateTextUsesCurrentFont() {
        let ec = editor(withText: false)
        ec.currentItem.fontFamily = FontFamily.cascadia
        ec.currentItem.fontSize = 32
        let id = ec.createText(at: Point(0, 0))
        guard case let .text(props) = ec.scene.element(id: id)?.kind else { return XCTFail("text") }
        XCTAssertEqual(props.fontFamily, FontFamily.cascadia)
        XCTAssertEqual(props.fontSize, 32)
    }

    func testUpdateSelectedTextFontSizeRecomputesHeight() {
        let ec = editor(withText: true)
        let h0 = ec.scene.element(id: "t")?.base.height ?? 0
        ec.updateSelectedText { $0.fontSize = 40 }
        guard case let .text(props) = ec.scene.element(id: "t")?.kind else { return XCTFail("text") }
        XCTAssertEqual(props.fontSize, 40)
        XCTAssertGreaterThan(ec.scene.element(id: "t")?.base.height ?? 0, h0) // grew
    }

    func testUpdateSelectedTextFamily() {
        let ec = editor(withText: true)
        ec.updateSelectedText { $0.fontFamily = FontFamily.helvetica }
        guard case let .text(props) = ec.scene.element(id: "t")?.kind else { return XCTFail("text") }
        XCTAssertEqual(props.fontFamily, FontFamily.helvetica)
    }

    func testFontChangeIsUndoable() {
        let ec = editor(withText: true)
        ec.updateSelectedText { $0.fontSize = 50 }
        XCTAssertTrue(ec.undo())
        guard case let .text(props) = ec.scene.element(id: "t")?.kind else { return XCTFail("text") }
        XCTAssertEqual(props.fontSize, 20)
    }

    func testUpdateSelectedTextNoOpWithoutText() {
        let ec = editor(withText: false)
        ec.updateSelectedText { $0.fontSize = 99 }
        XCTAssertFalse(ec.canUndo)
    }
}
