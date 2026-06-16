import ExcalidrawMetal
import ExcalidrawRender
import XCTest
@testable import ExcalidrawUI

@MainActor
final class RendererToggleTests: XCTestCase {
    func testDefaultsToCoreGraphics() {
        let m = EditorModel()
        XCTAssertEqual(m.rendererKind, .coreGraphics)
        XCTAssertTrue(m.renderer is SceneRenderer)
    }

    func testSwitchingToMetalWhenSupported() throws {
        guard MetalSceneRenderer.isSupported else {
            throw XCTSkip("No Metal device on this host")
        }
        let m = EditorModel()
        let before = m.revision
        m.setRenderer(.metal)
        XCTAssertEqual(m.rendererKind, .metal)
        XCTAssertTrue(m.renderer is MetalSceneRenderer)
        XCTAssertGreaterThan(m.revision, before, "switching backends triggers a repaint")
    }

    func testSwitchingBackToCoreGraphics() throws {
        guard MetalSceneRenderer.isSupported else {
            throw XCTSkip("No Metal device on this host")
        }
        let m = EditorModel()
        m.setRenderer(.metal)
        m.setRenderer(.coreGraphics)
        XCTAssertEqual(m.rendererKind, .coreGraphics)
        XCTAssertTrue(m.renderer is SceneRenderer)
    }

    func testToggleMatchesAvailability() {
        let m = EditorModel()
        m.toggleRenderer()
        // Toggling to Metal succeeds only when supported; otherwise it falls
        // back to Core Graphics so rendering never breaks.
        if MetalSceneRenderer.isSupported {
            XCTAssertEqual(m.rendererKind, .metal)
        } else {
            XCTAssertEqual(m.rendererKind, .coreGraphics)
        }
    }

    func testIsMetalAvailableMatchesContext() {
        let m = EditorModel()
        XCTAssertEqual(m.isMetalAvailable, MetalSceneRenderer.isSupported)
    }
}
