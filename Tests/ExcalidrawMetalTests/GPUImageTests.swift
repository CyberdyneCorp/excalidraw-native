import CoreGraphics
import ExcalidrawMath
import ExcalidrawModel
import ExcalidrawRender
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ExcalidrawMetal

/// Image elements rendered as GPU textured quads: z-ordered draw commands,
/// UV/crop handling, and an end-to-end render against a real device.
final class GPUImageTests: XCTestCase {
    private func base(_ id: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double) -> BaseProperties {
        var b = BaseProperties(id: id); b.x = x; b.y = y; b.width = w; b.height = h; b.seed = 7
        b.strokeColor = "#1e1e1e"
        return b
    }

    private func imageElement(_ id: String, _ x: Double, _ y: Double, fileId: String, crop: ImageCrop? = nil)
        -> ExcalidrawElement {
        ExcalidrawElement(base: base(id, x, y, 80, 60), kind: .image(ImageProperties(fileId: fileId, crop: crop)))
    }

    func testImageBreaksTriangleRunForZOrder() {
        let scene = Scene(elements: [
            ExcalidrawElement(base: base("r1", 0, 0, 50, 50), kind: .rectangle),
            imageElement("img", 60, 0, fileId: "f1"),
            ExcalidrawElement(base: base("r2", 120, 0, 50, 50), kind: .rectangle)
        ])
        let g = SceneGeometry(scene: scene, theme: .light)
        XCTAssertEqual(g.imageDraws.count, 1)
        XCTAssertTrue(g.handledIDs.contains("img"))
        XCTAssertFalse(g.hasOnlyTriangles)
        // Draw order: triangles (r1) → image → triangles (r2).
        XCTAssertEqual(g.drawCommands.count, 3)
        if case .triangles = g.drawCommands[0] {} else { XCTFail("expected triangles first") }
        if case .image(0) = g.drawCommands[1] {} else { XCTFail("expected image second") }
        if case .triangles = g.drawCommands[2] {} else { XCTFail("expected triangles third") }
    }

    func testSceneWithoutImagesHasOnlyTriangles() {
        let scene = Scene(elements: [ExcalidrawElement(base: base("r", 0, 0, 50, 50), kind: .rectangle)])
        let g = SceneGeometry(scene: scene, theme: .light)
        XCTAssertTrue(g.hasOnlyTriangles)
        XCTAssertTrue(g.imageDraws.isEmpty)
    }

    func testImageCropMapsToUVSubRect() {
        let crop = ImageCrop(x: 25, y: 50, width: 50, height: 50, naturalWidth: 100, naturalHeight: 200)
        let scene = Scene(elements: [imageElement("img", 0, 0, fileId: "f1", crop: crop)])
        let g = SceneGeometry(scene: scene, theme: .light)
        let uvs = g.imageDraws[0].uvs
        XCTAssertEqual(uvs[0].x, 0.25, accuracy: 1e-6) // 25/100
        XCTAssertEqual(uvs[0].y, 0.25, accuracy: 1e-6) // 50/200
        XCTAssertEqual(uvs[2].x, 0.75, accuracy: 1e-6) // (25+50)/100
        XCTAssertEqual(uvs[2].y, 0.50, accuracy: 1e-6) // (50+50)/200
    }

    func testGPURendersAnImageElement() throws {
        guard let metal = MetalSceneRenderer() else {
            throw XCTSkip("No Metal device on this host")
        }
        let size = CGSize(width: 120, height: 100)
        // A solid blue 8×8 image filling most of the canvas.
        let dataURL = try Self.solidColorPNGDataURL(red: 0, green: 0, blue: 1)
        let file = BinaryFileData(mimeType: "image/png", id: "f1", dataURL: dataURL, created: 0)
        var imgBase = base("img", 10, 10, 100, 80)
        imgBase.strokeColor = "#000000"
        let scene = Scene(
            elements: [ExcalidrawElement(base: imgBase, kind: .image(ImageProperties(fileId: "f1")))],
            files: ["f1": file]
        )

        let pixels = render(scene, size: size, with: metal)
        // Centre of the image must be blue.
        let i = (50 * Int(size.width) + 60) * 4
        XCTAssertLessThan(Int(pixels[i]), 80, "red channel low")
        XCTAssertLessThan(Int(pixels[i + 1]), 80, "green channel low")
        XCTAssertGreaterThan(Int(pixels[i + 2]), 180, "blue channel high")
    }

    private func render(_ scene: Scene, size: CGSize, with renderer: MetalSceneRenderer) -> [UInt8] {
        let w = Int(size.width), h = Int(size.height)
        let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        renderer.render(scene, in: ctx, viewport: Viewport(), size: size, theme: .light)
        let data = ctx.data!
        return [UInt8](UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: w * h * 4))
    }

    /// A base64 `data:` URL for an 8×8 solid-color PNG.
    private static func solidColorPNGDataURL(red: CGFloat, green: CGFloat, blue: CGFloat) throws -> String {
        let size = 8
        let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let cgImage = try XCTUnwrap(ctx.makeImage())
        let data = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, cgImage, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return "data:image/png;base64," + (data as Data).base64EncodedString()
    }
}
