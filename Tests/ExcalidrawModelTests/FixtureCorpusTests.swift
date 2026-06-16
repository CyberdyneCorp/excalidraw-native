import ExcalidrawMath
import XCTest
@testable import ExcalidrawModel

/// Exercises the broader fixture corpus to harden interop fidelity.
final class FixtureCorpusTests: XCTestCase {
    func testAllElementsModelRoundTrips() throws {
        let data = try Fixtures.data("all_elements.excalidraw")
        let file = try ExcalidrawFile.decode(from: data)
        XCTAssertEqual(file.elements.count, 7)
        let reloaded = try ExcalidrawFile.decode(from: file.jsonData())
        XCTAssertEqual(file, reloaded)
    }

    func testAllElementsIsDiffClean() throws {
        let data = try Fixtures.data("all_elements.excalidraw")
        let file = try ExcalidrawFile.decode(from: data)
        try assertJSONSemanticallyEqual(data, file.jsonData())
    }

    func testAllElementsParsedDetails() throws {
        let file = try ExcalidrawFile.decode(from: Fixtures.data("all_elements.excalidraw"))
        let byID = Dictionary(file.elements.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        guard case let .arrow(arrow) = byID["arrow-1"]?.kind else { return XCTFail("arrow") }
        XCTAssertEqual(arrow.startBinding?.elementId, "ellipse-1")
        XCTAssertEqual(arrow.startBinding?.mode, .orbit)
        XCTAssertEqual(arrow.endArrowhead, .triangle)

        guard case let .line(line) = byID["line-1"]?.kind else { return XCTFail("line") }
        XCTAssertTrue(line.polygon)

        guard case let .image(image) = byID["image-1"]?.kind else { return XCTFail("image") }
        XCTAssertEqual(image.status, .saved)
        XCTAssertEqual(image.fileId, "file-abc")
        XCTAssertEqual(file.files["file-abc"]?.mimeType, "image/png")

        guard case let .frame(name) = byID["frame-1"]?.kind else { return XCTFail("frame") }
        XCTAssertEqual(name, "My Frame")
        XCTAssertEqual(byID["diamond-1"]?.base.frameId, "frame-1")
        XCTAssertEqual(byID["ellipse-1"]?.base.boundElements?.first?.type, .arrow)
    }

    func testLegacyFileLoadsAndRestores() throws {
        let file = try ExcalidrawFile.decode(from: Fixtures.data("legacy_minimal.excalidraw"))
        XCTAssertEqual(file.version, 1)
        // Missing fields fall back to defaults.
        let rect = file.elements[0]
        XCTAssertEqual(rect.base.fillStyle, .solid)
        XCTAssertEqual(rect.base.opacity, 100)
        XCTAssertNil(rect.base.index)

        // Restore canonicalises: version upgraded, indices assigned.
        let restored = Restore.restore(file)
        XCTAssertEqual(restored.version, 2)
        XCTAssertFalse(restored.elements.contains { $0.base.index == nil })
    }
}
