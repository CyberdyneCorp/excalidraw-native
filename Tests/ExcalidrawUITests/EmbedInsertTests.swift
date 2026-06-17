import ExcalidrawModel
import XCTest
@testable import ExcalidrawUI

@MainActor
final class EmbedInsertTests: XCTestCase {
    func testCommitEmbedInsertsEmbeddableWithLink() {
        let model = EditorModel()
        model.embedURLText = "https://youtu.be/abc123"
        model.commitEmbed()
        XCTAssertFalse(model.showEmbedPrompt)
        let embed = model.controller.scene.visibleElements.first { $0.type == "embeddable" }
        XCTAssertNotNil(embed)
        XCTAssertEqual(embed?.base.link, "https://youtu.be/abc123")
    }

    func testCommitEmbedWithEmptyURLIsNoOp() {
        let model = EditorModel()
        model.embedURLText = "   "
        model.commitEmbed()
        XCTAssertTrue(model.controller.scene.visibleElements.isEmpty)
    }
}
