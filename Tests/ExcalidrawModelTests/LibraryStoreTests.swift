import Foundation
import XCTest
@testable import ExcalidrawModel

final class LibraryStoreTests: XCTestCase {
    private func tempStore() -> LibraryStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("store-\(UUID().uuidString)/library.excalidrawlib")
        return LibraryStore(url: url)
    }

    private func item(_ id: String) -> [ExcalidrawElement] {
        var base = BaseProperties(id: id); base.width = 40; base.height = 20
        return [ExcalidrawElement(base: base, kind: .rectangle)]
    }

    func testLoadMissingFileReturnsEmpty() throws {
        XCTAssertTrue(try tempStore().load().isEmpty)
    }

    func testSaveLoadRoundTripCreatesDirectory() throws {
        let store = tempStore()
        try store.save([item("a"), item("b")])
        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].first?.id, "a")
    }

    func testSaveOverwrites() throws {
        let store = tempStore()
        try store.save([item("a")])
        try store.save([])
        XCTAssertTrue(try store.load().isEmpty)
    }

    func testDefaultStorePathEndsWithLibraryFile() {
        XCTAssertEqual(LibraryStore.defaultStore().url.lastPathComponent, "library.excalidrawlib")
    }
}
