import CoreGraphics
import ExcalidrawMath
import ExcalidrawModel
import ExcalidrawRender
import XCTest

/// On-device rendering benchmark (Phase 7.5). App-hosted so it can import the
/// render modules and run `SceneRenderer` in-process on a real iPad/iPhone:
///
///   xcodebuild test -scheme ExcalidrawApp \
///     -destination 'platform=iOS,id=<device-udid>' \
///     -only-testing:ExcalidrawAppBenchmarks
///
/// Read the printed `DEVICE BENCH` lines for the numbers. Asserts only the
/// Stage-B invariant (a layered frame is cheaper than a full repaint), never an
/// absolute wall-clock time, so it won't flake.
final class RenderDeviceBenchmark: XCTestCase {
    private func context(_ w: Int, _ h: Int) -> CGContext {
        CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    private func syntheticScene(count: Int) -> Scene {
        let perRow = Int(Double(count).squareRoot().rounded(.up))
        let cell = 90.0
        var elements: [ExcalidrawElement] = []
        for i in 0 ..< count {
            var b = BaseProperties(id: "e\(i)")
            b.x = Double(i % perRow) * cell + 10
            b.y = Double(i / perRow) * cell + 10
            b.width = 70; b.height = 60; b.seed = i + 1; b.strokeColor = "#1e1e1e"
            switch i % 5 {
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
                    base: b,
                    kind: .arrow(ArrowProperties(points: pts, endArrowhead: .arrow))
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

    func testFullVsLayeredOnDevice() throws {
        let (w, h) = (1200, 800)
        let size = CGSize(width: w, height: h)
        let viewport = Viewport()
        let renderer = SceneRenderer()

        for count in [500, 1500] {
            let scene = syntheticScene(count: count)
            let allIDs = Set(scene.visibleElements.map(\.id))
            let dynamic: Set = ["e0"]

            let fullCtx = context(w, h)
            renderer.render(scene, in: fullCtx, viewport: viewport, size: size) // warm
            let fullMs = milliseconds(10) { renderer.render(scene, in: fullCtx, viewport: viewport, size: size) }

            let staticCtx = context(w, h)
            renderer.render(scene, in: staticCtx, viewport: viewport, size: size, skipping: dynamic)
            let staticImage = try XCTUnwrap(staticCtx.makeImage())
            let frameCtx = context(w, h)
            let layeredMs = milliseconds(10) {
                frameCtx.draw(staticImage, in: CGRect(x: 0, y: 0, width: w, height: h))
                renderer.render(
                    scene, in: frameCtx, viewport: viewport, size: size,
                    skipping: allIDs.subtracting(dynamic), fillBackground: false
                )
            }

            print(String(
                format: "DEVICE BENCH n=%4d  full=%.2f ms  layered=%.2f ms  (%.1fx)",
                count, fullMs, layeredMs, fullMs / layeredMs
            ))
            XCTAssertLessThan(layeredMs, fullMs)
        }
    }
}
