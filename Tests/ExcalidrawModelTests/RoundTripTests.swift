import ExcalidrawMath
import XCTest
@testable import ExcalidrawModel

final class RoundTripTests: XCTestCase {
    func testMinimalSceneModelRoundTrips() throws {
        let original = try Fixtures.data("minimal_scene.excalidraw")
        let fileA = try ExcalidrawFile.decode(from: original)

        // Encode -> decode must be a fixed point (model equality is the strong check).
        let reencoded = try fileA.jsonData()
        let fileB = try ExcalidrawFile.decode(from: reencoded)
        XCTAssertEqual(fileA, fileB)
    }

    func testMinimalSceneIsDiffCleanAgainstSource() throws {
        let original = try Fixtures.data("minimal_scene.excalidraw")
        let file = try ExcalidrawFile.decode(from: original)
        let reencoded = try file.jsonData()
        // No fields dropped or altered (ignoring formatting / null-vs-absent).
        assertJSONSemanticallyEqual(original, reencoded)
    }

    func testMilestoneLoadMutateSave() throws {
        // Phase 1 milestone: load a real file, mutate via the API, save it back.
        let original = try Fixtures.data("minimal_scene.excalidraw")
        var scene = try Scene(file: ExcalidrawFile.decode(from: original))

        XCTAssertEqual(scene.element(id: "rect-1")?.base.version, 1)
        let didMutate = scene.mutate(id: "rect-1", timestamp: 1_700_000_001_000) {
            $0.base.x = 150
            $0.base.strokeColor = "#e03131"
        }
        XCTAssertTrue(didMutate)

        let saved = scene.toFile()
        let reloaded = try Scene(file: ExcalidrawFile.decode(from: saved.jsonData()))
        let rect = try XCTUnwrap(reloaded.element(id: "rect-1"))
        XCTAssertEqual(rect.base.x, 150)
        XCTAssertEqual(rect.base.strokeColor, "#e03131")
        XCTAssertEqual(rect.base.version, 2) // bumped by mutate
        XCTAssertEqual(rect.base.updated, 1_700_000_001_000)
    }

    func testParsesElementKinds() throws {
        let file = try ExcalidrawFile.decode(from: Fixtures.data("minimal_scene.excalidraw"))
        XCTAssertEqual(file.elements.count, 2)
        guard case .rectangle = file.elements[0].kind else {
            return XCTFail("expected rectangle")
        }
        guard case let .text(text) = file.elements[1].kind else {
            return XCTFail("expected text")
        }
        XCTAssertEqual(text.text, "Hello")
        XCTAssertEqual(text.fontFamily, FontFamily.excalifont)
    }
}
