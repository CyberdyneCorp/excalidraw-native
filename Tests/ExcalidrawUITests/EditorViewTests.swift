import ExcalidrawModel
import SwiftUI
import XCTest
@testable import ExcalidrawUI

@MainActor
final class EditorViewTests: XCTestCase {
    func testConstructsAndProducesBody() {
        var base = BaseProperties(id: "r")
        base.width = 100; base.height = 60
        let scene = ExcalidrawModel.Scene(elements: [ExcalidrawElement(base: base, kind: .rectangle)])
        let view = EditorView(scene: scene)
        _ = view.body
    }

    func testColorHexInit() {
        // Exercises the palette hex → Color helper.
        _ = Color(hex: "#1971c2")
        _ = Color(hex: "ff0000")
    }
}
