import ExcalidrawMetal
import ExcalidrawModel
import XCTest
@testable import ExcalidrawUI

final class RendererBenchmarkTests: XCTestCase {
    func testSyntheticSceneSizesAndKinds() {
        let shapes = RendererBenchmark.syntheticScene(count: 40, shapesOnly: true)
        XCTAssertEqual(shapes.visibleElements.count, 40)
        // shapesOnly cycles through 4 GPU-tessellated kinds — no freedraw.
        XCTAssertFalse(shapes.visibleElements.contains { $0.type == "freedraw" })

        let mixed = RendererBenchmark.syntheticScene(count: 40, shapesOnly: false)
        XCTAssertTrue(mixed.visibleElements.contains { $0.type == "freedraw" })
    }

    func testRunProducesRowsWithPositiveCPUTimes() {
        let configs = [RendererBenchmark.Config(label: "shapes", shapesOnly: true, count: 60)]
        let rows = RendererBenchmark.run(width: 400, height: 300, iterations: 1, configs: configs)
        XCTAssertEqual(rows.count, 1)
        let row = try? XCTUnwrap(rows.first)
        XCTAssertEqual(row?.count, 60)
        XCTAssertGreaterThan(row?.cpuMs ?? 0, 0)
    }

    func testRunPopulatesMetalPhasesWhenAvailable() throws {
        try XCTSkipUnless(RendererBenchmark.metalAvailable, "No Metal device on this host")
        let configs = [RendererBenchmark.Config(label: "shapes", shapesOnly: true, count: 60)]
        let row = try XCTUnwrap(
            RendererBenchmark.run(width: 400, height: 300, iterations: 1, configs: configs).first
        )
        XCTAssertNotNil(row.metalMs)
        XCTAssertNotNil(row.gpuMs)
        // Ratio is defined once a Metal time exists.
        XCTAssertNotNil(row.ratio)
    }

    func testMetalAvailabilityMatchesContext() {
        XCTAssertEqual(RendererBenchmark.metalAvailable, MetalSceneRenderer.isSupported)
    }
}
