import XCTest
@testable import ExcalidrawModel

final class SceneDocumentTests: XCTestCase {
    private func rect(_ id: String, index: String?) -> ExcalidrawElement {
        var b = BaseProperties(id: id); b.width = 30; b.height = 20; b.index = index
        return ExcalidrawElement(base: b, kind: .rectangle)
    }

    func testEncodeDecodeRoundTrip() throws {
        let scene = Scene(elements: [rect("a", index: "a0"), rect("b", index: "a1")])
        let data = try SceneDocument.encode(scene)
        let reloaded = try SceneDocument.decode(data)
        XCTAssertEqual(reloaded.elements.map(\.id), ["a", "b"])
    }

    func testDecodeAppliesRestore() throws {
        // Elements without indices get them assigned on load.
        let scene = Scene(elements: [rect("a", index: nil), rect("b", index: nil)])
        let data = try SceneDocument.encode(scene)
        let reloaded = try SceneDocument.decode(data)
        XCTAssertFalse(reloaded.elements.contains { $0.base.index == nil })
    }

    func testDecodeOfFixtureFile() throws {
        let data = try Fixtures.data("minimal_scene.excalidraw")
        let scene = try SceneDocument.decode(data)
        XCTAssertEqual(scene.visibleElements.count, 2)
    }
}
