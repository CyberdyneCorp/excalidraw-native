import ExcalidrawModel
import XCTest
@testable import ExcalidrawEditor

final class CopyPasteTests: XCTestCase {
    private func makeEditor(_ elements: [ExcalidrawElement] = []) -> EditorController {
        var idCount = 100
        return EditorController(scene: Scene(elements: elements), idProvider: { idCount += 1; return "n\(idCount)" })
    }

    private func rect(_ id: String) -> ExcalidrawElement {
        var b = BaseProperties(id: id); b.width = 30; b.height = 20
        return ExcalidrawElement(base: b, kind: .rectangle)
    }

    func testCopyNilWhenEmptySelection() {
        XCTAssertNil(makeEditor([rect("a")]).copyData())
    }

    func testCopyPasteRoundTrip() throws {
        let ec = makeEditor([rect("a")])
        ec.selectAll()
        let data = try? XCTUnwrap(ec.copyData())
        XCTAssertNotNil(data)

        try ec.paste(XCTUnwrap(data))
        XCTAssertEqual(ec.scene.visibleElements.count, 2)
        // Pasted copy is offset and freshly selected (not the original).
        XCTAssertFalse(ec.selectedIDs.contains("a"))
        let copy = ec.selectedElements.first
        XCTAssertEqual(copy?.base.x, 10)
    }

    func testPasteIgnoresGarbage() {
        let ec = makeEditor([rect("a")])
        ec.paste(Data("not json".utf8))
        XCTAssertEqual(ec.scene.visibleElements.count, 1)
    }

    func testCopyIncludesImageFiles() throws {
        var img = BaseProperties(id: "i"); img.width = 10; img.height = 10
        let file = BinaryFileData(mimeType: "image/png", id: "f1", dataURL: "data:image/png;base64,AA==", created: 0)
        let scene = Scene(
            elements: [ExcalidrawElement(base: img, kind: .image(ImageProperties(fileId: "f1", status: .saved)))],
            files: ["f1": file]
        )
        var idCount = 0
        let ec = EditorController(scene: scene, idProvider: { idCount += 1; return "n\(idCount)" })
        ec.selectAll()
        let data = try? XCTUnwrap(ec.copyData())
        let file2 = try? ExcalidrawFile.decode(from: try XCTUnwrap(data))
        XCTAssertEqual(file2?.files["f1"]?.mimeType, "image/png")
    }
}
