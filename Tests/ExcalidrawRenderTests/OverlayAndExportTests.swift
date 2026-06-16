import CoreGraphics
import ExcalidrawGeometry
import ExcalidrawMath
import ExcalidrawModel
import XCTest
@testable import ExcalidrawRender

final class OverlayAndExportTests: XCTestCase {
    private func context(_ w: Int, _ h: Int) -> CGContext {
        CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    private func inked(_ ctx: CGContext, _ w: Int, _ h: Int) -> Int {
        let px = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var count = 0
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            let isClear = px[i] == 0 && px[i + 1] == 0 && px[i + 2] == 0 && px[i + 3] == 0
            if !isClear { count += 1 }
        }
        return count
    }

    func testOverlayDrawsSelectionAndHandles() {
        let (w, h) = (200, 200)
        let ctx = context(w, h)
        let bounds = BoundingBox(minX: 40, minY: 40, maxX: 120, maxY: 120)
        let handles = Array(handlePoints(bounds))
        InteractiveRenderer.render(
            selectionBounds: bounds, handles: handles, rotationHandle: Point(80, 10),
            selectionRect: nil, in: ctx, viewport: Viewport()
        )
        XCTAssertGreaterThan(inked(ctx, w, h), 50)
    }

    func testOverlayDrawsMarquee() {
        let (w, h) = (200, 200)
        let ctx = context(w, h)
        InteractiveRenderer.render(
            selectionBounds: nil, handles: [], rotationHandle: nil,
            selectionRect: BoundingBox(minX: 20, minY: 20, maxX: 150, maxY: 150),
            in: ctx, viewport: Viewport()
        )
        XCTAssertGreaterThan(inked(ctx, w, h), 50)
    }

    func testExportProducesPNG() throws {
        var b = BaseProperties(id: "r"); b.x = 30; b.y = 30; b.width = 100; b.height = 60
        b.backgroundColor = "#ff0000"; b.fillStyle = .solid
        let scene = Scene(elements: [ExcalidrawElement(base: b, kind: .rectangle)])
        let data = Exporter.pngData(scene, options: .init(scale: 2, padding: 10))
        let png = try? XCTUnwrap(data)
        XCTAssertNotNil(png)
        // PNG magic number.
        XCTAssertEqual(try Array(XCTUnwrap(png?.prefix(4))), [0x89, 0x50, 0x4E, 0x47])

        // Dimensions = (content + 2*padding) * scale.
        let image = try XCTUnwrap(Exporter.cgImage(scene, options: .init(scale: 2, padding: 10)))
        XCTAssertEqual(image.width, Int((100.0 + 20) * 2))
        XCTAssertEqual(image.height, Int((60.0 + 20) * 2))
    }

    func testExportEmptySceneReturnsNil() {
        XCTAssertNil(Exporter.pngData(Scene()))
    }

    /// Local helper mirroring the editor's handle layout for the overlay test.
    private func handlePoints(_ b: BoundingBox) -> [Point] {
        let midX = (b.minX + b.maxX) / 2, midY = (b.minY + b.maxY) / 2
        return [
            Point(b.minX, b.minY), Point(midX, b.minY), Point(b.maxX, b.minY),
            Point(b.maxX, midY), Point(b.maxX, b.maxY), Point(midX, b.maxY),
            Point(b.minX, b.maxY), Point(b.minX, midY)
        ]
    }
}
