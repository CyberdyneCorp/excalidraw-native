import CoreGraphics
import ExcalidrawMath
import ExcalidrawMetal
import ExcalidrawModel
import ExcalidrawRender
import XCTest

/// On-device stress benchmark comparing the Core Graphics (CPU) renderer with
/// the Metal (GPU) renderer on the same scenes. App-hosted so it runs the real
/// `MetalSceneRenderer` (GPU device + shader compile + readback) in-process on a
/// real iPad/iPhone:
///
///   xcodebuild test -scheme ExcalidrawApp \
///     -destination 'platform=iOS,id=<device-udid>' \
///     -only-testing:ExcalidrawAppBenchmarks/RendererComparisonBenchmark
///
/// Read the printed `RENDERER BENCH` lines for the numbers. The test asserts
/// only that both backends produce a non-empty image (never an absolute or
/// relative wall-clock time) so it can't flake on hardware where readback
/// overhead outweighs GPU throughput at a given scene size.
final class RendererComparisonBenchmark: XCTestCase {
    private let width = 1200
    private let height = 800

    private func context() -> CGContext {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    /// A grid of mixed elements. `shapesOnly` keeps only the GPU-tessellated
    /// kinds (rect/ellipse/diamond/arrow) — the Metal best case — while the
    /// default mix adds freedraw, which the Metal path routes back to CG.
    private func syntheticScene(count: Int, shapesOnly: Bool) -> Scene {
        let perRow = Int(Double(count).squareRoot().rounded(.up))
        let cell = 90.0
        var elements: [ExcalidrawElement] = []
        let kinds = shapesOnly ? 4 : 5
        for i in 0 ..< count {
            var b = BaseProperties(id: "e\(i)")
            b.x = Double(i % perRow) * cell + 10
            b.y = Double(i / perRow) * cell + 10
            b.width = 70; b.height = 60; b.seed = i + 1; b.strokeColor = "#1e1e1e"
            switch i % kinds {
            case 0:
                b.backgroundColor = "#ffc9c9"; b.fillStyle = .hachure
                elements.append(ExcalidrawElement(base: b, kind: .rectangle))
            case 1:
                b.backgroundColor = "#a5d8ff"; b.fillStyle = .crossHatch
                elements.append(ExcalidrawElement(base: b, kind: .ellipse))
            case 2:
                b.backgroundColor = "#b2f2bb"; b.fillStyle = .solid
                elements.append(ExcalidrawElement(base: b, kind: .diamond))
            case 3:
                let pts = [Point(0, 0), Point(70, 20), Point(20, 60), Point(70, 60)]
                elements.append(ExcalidrawElement(
                    base: b, kind: .arrow(ArrowProperties(points: pts, endArrowhead: .arrow))
                ))
            default:
                let pts = (0 ..< 200).map { j in Point(Double(j % 70), Double((j * 7) % 60)) }
                elements.append(ExcalidrawElement(base: b, kind: .freedraw(FreedrawProperties(points: pts))))
            }
        }
        return Scene(elements: elements)
    }

    private func milliseconds(_ iterations: Int, _ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0 ..< iterations {
            body()
        }
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6 / Double(iterations)
    }

    private func inkFraction(_ ctx: CGContext) -> Double {
        guard let data = ctx.data else { return 0 }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let total = width * height
        var ink = 0
        for i in 0 ..< total {
            let p = i * 4
            if Int(pixels[p]) + Int(pixels[p + 1]) + Int(pixels[p + 2]) < 600 { ink += 1 }
        }
        return Double(ink) / Double(total)
    }

    /// Head-to-head: CPU (Core Graphics) vs GPU (Metal) wall-clock per frame on
    /// the same scenes, plus a Metal phase breakdown (geometry / background / GPU
    /// / overlay) so the cost split is visible. `shapes-only` is the Metal best
    /// case (every element is GPU-tessellated); `mixed` adds freedraw, which the
    /// Metal path routes back to Core Graphics. Asserts only that both backends
    /// paint the scene — never a wall-clock target — so it can't flake.
    func testMetalVsCoreGraphicsOnDevice() throws {
        guard let metal = MetalSceneRenderer() else {
            throw XCTSkip("No Metal device on this host")
        }
        let cg = SceneRenderer()
        let size = CGSize(width: width, height: height)
        let viewport = Viewport()

        for shapesOnly in [true, false] {
            let label = shapesOnly ? "shapes-only" : "mixed"
            for count in [500, 1500] {
                let scene = syntheticScene(count: count, shapesOnly: shapesOnly)

                let cgCtx = context()
                cg.render(scene, in: cgCtx, viewport: viewport, size: size) // warm
                let cgMs = milliseconds(5) { cg.render(scene, in: cgCtx, viewport: viewport, size: size) }

                let metalCtx = context()
                metal.render(scene, in: metalCtx, viewport: viewport, size: size) // warm shader + caches
                let metalMs = milliseconds(5) { metal.render(scene, in: metalCtx, viewport: viewport, size: size) }
                let t = metal.renderTimed(scene, in: context(), viewport: viewport, size: size)

                XCTAssertGreaterThan(inkFraction(cgCtx), 0.01, "\(label) n=\(count): CG drew nothing")
                XCTAssertGreaterThan(inkFraction(metalCtx), 0.01, "\(label) n=\(count): Metal drew nothing")
                print(String(
                    format: "RENDERER BENCH %-11@ n=%4d  cpu=%6.1f ms  metal=%6.1f ms  (%.2fx)  "
                        + "[geom=%.1f bg=%.1f gpu=%.1f overlay=%.1f]",
                    label as NSString, count, cgMs, metalMs, cgMs / metalMs,
                    t.geometryMs, t.backgroundMs, t.gpuMs, t.overlayMs
                ))
            }
        }
    }
}
