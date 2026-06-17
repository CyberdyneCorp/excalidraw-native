import CoreGraphics
import Foundation
import XCTest
@testable import ExcalidrawUI

final class DocumentStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        DocumentStore.clearRecents()
        DocumentStore.clearAutosave()
    }

    func testAutosaveRoundTrip() {
        let data = Data("hello".utf8)
        DocumentStore.saveAutosave(data)
        XCTAssertEqual(DocumentStore.loadAutosave(), data)
        DocumentStore.clearAutosave()
        XCTAssertNil(DocumentStore.loadAutosave())
    }

    func testRecentsAddAndDedupe() throws {
        let dir = FileManager.default.temporaryDirectory
        let a = dir.appendingPathComponent("a.excalidraw")
        let b = dir.appendingPathComponent("b.excalidraw")
        try Data("a".utf8).write(to: a)
        try Data("b".utf8).write(to: b)

        DocumentStore.addRecent(a)
        DocumentStore.addRecent(b)
        DocumentStore.addRecent(a) // re-adding moves it to front, no duplicate
        let recents = DocumentStore.recents()
        XCTAssertEqual(recents.first?.lastPathComponent, "a.excalidraw")
        XCTAssertEqual(recents.count(where: { $0.lastPathComponent == "a.excalidraw" }), 1)
    }
}

@MainActor
final class DocumentRoundTripTests: XCTestCase {
    override func setUp() {
        super.setUp()
        DocumentStore.clearAutosave()
    }

    private func drawRect(_ model: EditorModel) {
        model.setBackgroundColor("#a5d8ff")
        model.select(tool: .rectangle)
        model.pointer(.down, at: CGPoint(x: 10, y: 10))
        model.pointer(.move, at: CGPoint(x: 90, y: 60))
        model.pointer(.up, at: CGPoint(x: 90, y: 60))
    }

    func testSaveAndOpenDocument() {
        let source = EditorModel()
        drawRect(source)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rt-\(UUID()).excalidraw")
        XCTAssertTrue(source.saveDocument(to: url))

        let target = EditorModel()
        XCTAssertTrue(target.openDocument(at: url))
        XCTAssertEqual(target.controller.scene.visibleElements.count, 1)
        XCTAssertEqual(target.controller.scene.visibleElements.first?.type, "rectangle")
    }

    func testAutosaveRestoresOnlyWhenEmpty() {
        let source = EditorModel()
        drawRect(source)
        source.autosave()

        // A fresh, empty editor restores the autosave.
        let fresh = EditorModel()
        fresh.restoreAutosaveIfEmpty()
        XCTAssertEqual(fresh.controller.scene.visibleElements.count, 1)

        // A non-empty editor is not clobbered.
        let busy = EditorModel()
        drawRect(busy)
        busy.select(tool: .ellipse)
        busy.pointer(.down, at: CGPoint(x: 100, y: 100))
        busy.pointer(.up, at: CGPoint(x: 140, y: 140))
        let before = busy.controller.scene.visibleElements.count
        busy.restoreAutosaveIfEmpty()
        XCTAssertEqual(busy.controller.scene.visibleElements.count, before)
    }
}
