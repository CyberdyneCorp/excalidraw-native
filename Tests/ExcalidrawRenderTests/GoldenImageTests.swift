import CoreGraphics
import ExcalidrawMath
import ExcalidrawModel
import Foundation
import ImageIO
import XCTest
@testable import ExcalidrawRender

/// Stage-A golden-image safety net (Phase 7.5): render canonical, deterministic
/// (shapes-only, seeded — no text/images, which vary by OS font) scenes and
/// diff them against committed PNG references. This is the regression net for
/// every later renderer change (layered split, tiles, Metal).
///
/// References live in `Golden/` next to this file. On first run (or when a
/// reference is missing) the image is written and the check passes; commit the
/// PNGs so later runs compare. Comparison is tolerant (a small fraction of
/// pixels may differ by a small amount) so antialiasing noise across machines
/// doesn't flake, while real changes are caught.
final class GoldenImageTests: XCTestCase {
    private let size = CGSize(width: 320, height: 200)
    /// Max fraction of pixels allowed to differ beyond `channelThreshold`.
    private let tolerance = 0.02
    private let channelThreshold: UInt8 = 24

    private func base(_ id: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double) -> BaseProperties {
        var b = BaseProperties(id: id); b.x = x; b.y = y; b.width = w; b.height = h; b.seed = 7
        b.strokeColor = "#1e1e1e"
        return b
    }

    func testGoldenShapesWithFills() {
        var rect = base("r", 16, 20, 120, 70); rect.backgroundColor = "#ffc9c9"; rect.fillStyle = .hachure
        var ell = base("e", 170, 20, 120, 70); ell.backgroundColor = "#a5d8ff"; ell.fillStyle = .crossHatch
        var dia = base("d", 90, 110, 120, 70); dia.backgroundColor = "#b2f2bb"; dia.fillStyle = .solid
        assertGolden(Scene(elements: [
            ExcalidrawElement(base: rect, kind: .rectangle),
            ExcalidrawElement(base: ell, kind: .ellipse),
            ExcalidrawElement(base: dia, kind: .diamond)
        ]), name: "shapes-fills")
    }

    func testGoldenStrokesAndArrow() {
        let line = base("l", 16, 30, 130, 0)
        let arrow = base("a", 170, 30, 120, 80)
        var dashed = base("dr", 40, 110, 240, 60); dashed.strokeStyle = .dashed
        assertGolden(Scene(elements: [
            ExcalidrawElement(base: line, kind: .line(LinearProperties(points: [Point(0, 0), Point(130, 40)]))),
            ExcalidrawElement(
                base: arrow,
                kind: .arrow(ArrowProperties(points: [Point(0, 0), Point(120, 80)], endArrowhead: .arrow))
            ),
            ExcalidrawElement(base: dashed, kind: .rectangle)
        ]), name: "strokes-arrow")
    }

    func testGoldenRoundedAndSpline() {
        var rounded = base("rr", 16, 20, 130, 80); rounded.roundness = Roundness(type: RoundnessType.adaptiveRadius)
        var spline = base("sp", 170, 20, 120, 120)
        spline.roundness = Roundness(type: RoundnessType.proportionalRadius)
        let pts = [Point(0, 0), Point(120, 30), Point(20, 120)]
        assertGolden(Scene(elements: [
            ExcalidrawElement(base: rounded, kind: .rectangle),
            ExcalidrawElement(base: spline, kind: .line(LinearProperties(points: pts)))
        ]), name: "rounded-spline")
    }

    // MARK: Harness

    private func assertGolden(_ scene: Scene, name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let rendered = render(scene) else { return XCTFail("render failed", file: file, line: line) }
        let url = goldenURL(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            writePNG(rendered, to: url)
            print("GOLDEN recorded \(name).png — commit it so future runs compare")
            return
        }
        guard let reference = readImage(url)
        else { return XCTFail("can't read golden \(name)", file: file, line: line) }
        let diff = fractionDiffering(rendered, reference)
        XCTAssertLessThan(
            diff, tolerance,
            "\(name) differs from golden by \(String(format: "%.3f", diff)) (> \(tolerance))",
            file: file, line: line
        )
    }

    private func render(_ scene: Scene) -> CGImage? {
        let w = Int(size.width), h = Int(size.height)
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        SceneRenderer().render(scene, in: ctx, viewport: Viewport(), size: size)
        return ctx.makeImage()
    }

    /// Normalize any CGImage to a fixed RGBA8 byte buffer for comparison.
    private func pixels(_ image: CGImage) -> [UInt8] {
        let w = Int(size.width), h = Int(size.height)
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        buffer.withUnsafeMutableBytes { raw in
            let ctx = CGContext(
                data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            ctx?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return buffer
    }

    private func fractionDiffering(_ a: CGImage, _ b: CGImage) -> Double {
        let pa = pixels(a), pb = pixels(b)
        guard pa.count == pb.count, !pa.isEmpty else { return 1 }
        var differing = 0
        let pixelCount = pa.count / 4
        for i in stride(from: 0, to: pa.count, by: 4) {
            for c in 0 ..< 3 where abs(Int(pa[i + c]) - Int(pb[i + c])) > Int(channelThreshold) {
                differing += 1
                break
            }
        }
        return Double(differing) / Double(pixelCount)
    }

    private func goldenURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Golden")
            .appendingPathComponent("\(name).png")
    }

    private func writePNG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    private func readImage(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}
