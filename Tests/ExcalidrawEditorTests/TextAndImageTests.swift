import ExcalidrawMath
import ExcalidrawModel
import XCTest
@testable import ExcalidrawEditor

final class TextAndImageTests: XCTestCase {
    private func makeEditor() -> EditorController {
        var idCount = 0
        return EditorController(scene: Scene(), idProvider: { idCount += 1; return "n\(idCount)" })
    }

    func testCreateAndSetText() {
        let ec = makeEditor()
        let id = ec.createText(at: Point(10, 20))
        XCTAssertNotNil(ec.scene.element(id: id))
        ec.setText(id: id, "Hello\nworld")
        guard case let .text(props) = ec.scene.element(id: id)?.kind else { return XCTFail("text") }
        XCTAssertEqual(props.text, "Hello\nworld")
        XCTAssertGreaterThan(ec.scene.element(id: id)?.base.width ?? 0, 0)
        XCTAssertGreaterThan(ec.scene.element(id: id)?.base.height ?? 0, 0)
    }

    func testEmptyTextIsRemoved() {
        let ec = makeEditor()
        let id = ec.createText(at: Point(0, 0))
        ec.setText(id: id, "")
        XCTAssertNil(ec.scene.element(id: id))
        XCTAssertFalse(ec.selectedIDs.contains(id))
    }

    func testInsertImage() throws {
        let ec = makeEditor()
        let id = ec.insertImage(
            dataURL: "data:image/png;base64,AA==", mimeType: "image/png",
            at: Point(5, 5), width: 100, height: 80
        )
        guard case let .image(props) = ec.scene.element(id: id)?.kind else { return XCTFail("image") }
        XCTAssertEqual(props.status, .saved)
        let fileId = try? XCTUnwrap(props.fileId)
        XCTAssertEqual(try ec.scene.files[XCTUnwrap(fileId)]?.mimeType, "image/png")
        XCTAssertEqual(ec.scene.element(id: id)?.base.width, 100)
        XCTAssertTrue(ec.selectedIDs.contains(id))
    }

    func testTextEditIsUndoable() {
        let ec = makeEditor()
        let id = ec.createText(at: Point(0, 0))
        ec.setText(id: id, "x")
        XCTAssertEqual(ec.scene.element(id: id) != nil, true)
        // Creation + first edit are one undo step, so undo removes the element.
        XCTAssertTrue(ec.undo())
        XCTAssertNil(ec.scene.element(id: id))
    }
}
