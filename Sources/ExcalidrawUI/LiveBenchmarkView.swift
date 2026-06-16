import ExcalidrawMetal
import ExcalidrawModel
import ExcalidrawRender
import Foundation
import SwiftUI

/// Live visual stress test: continuously renders the synthetic benchmark scene
/// (panning + zooming every frame) with the selected backend so the elements are
/// visible on screen while a live FPS / frame-time readout shows the cost. Lets
/// you watch CPU vs Metal handle the same moving workload.
public struct LiveBenchmarkView: View {
    enum Backend: String, CaseIterable, Identifiable {
        case cpu = "CPU"
        case metal = "Metal"
        var id: String {
            rawValue
        }
    }

    @State private var backend: Backend = .cpu
    @State private var count = 500
    @State private var scene: ExcalidrawModel.Scene = RendererBenchmark.syntheticScene(count: 500, shapesOnly: false)
    @State private var cgRenderer = SceneRenderer()
    @State private var metalRenderer = MetalSceneRenderer()
    @State private var meter = FrameMeter()

    private let counts = [250, 500, 1000, 2000]

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            controls
            liveArea
        }
        .padding(12)
        .onChange(of: count) { _, new in
            scene = RendererBenchmark.syntheticScene(count: new, shapesOnly: false)
            meter.reset()
        }
        .onChange(of: backend) { _, _ in meter.reset() }
    }

    /// Readout + canvas inside one `TimelineView` so both re-evaluate every
    /// frame: the canvas renders the moving scene and the readout shows the
    /// latest FPS / frame time.
    private var liveArea: some View {
        TimelineView(.animation) { timeline in
            VStack(spacing: 8) {
                readout
                canvas(at: timeline.date)
                    .background(Color(white: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Backend", selection: $backend) {
                ForEach(Backend.allCases) { b in
                    Text(b.rawValue).tag(b)
                        // Metal disabled when unavailable.
                        .accessibilityIdentifier("live-backend-\(b.rawValue)")
                }
            }
            .pickerStyle(.segmented)
            .disabled(!RendererBenchmark.metalAvailable && backend == .cpu)
            Picker("Elements", selection: $count) {
                ForEach(counts, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("live-count")
        }
    }

    private var readout: some View {
        HStack(spacing: 16) {
            stat("FPS", String(format: "%.0f", meter.fps))
            stat("frame", String(format: "%.1f ms", meter.renderMs))
            stat("elements", "\(count)")
            Spacer()
            if backend == .metal, !RendererBenchmark.metalAvailable {
                Text("Metal N/A").font(.caption).foregroundStyle(.orange)
            }
        }
        .accessibilityIdentifier("live-readout")
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(.headline, design: .rounded)).monospacedDigit()
        }
    }

    private func canvas(at date: Date) -> some View {
        let viewport = animatedViewport(at: date)
        return Canvas { context, size in
            meter.tickFrame(date)
            context.withCGContext { cg in
                let start = DispatchTime.now().uptimeNanoseconds
                renderer.render(scene, in: cg, viewport: viewport, size: size, theme: .light)
                meter.recordRender(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
            }
        }
        .accessibilityIdentifier("live-canvas")
    }

    private var renderer: SceneRendering {
        if backend == .metal, let metalRenderer { return metalRenderer }
        return cgRenderer
    }

    /// Continuously pan and zoom so every frame is a fresh full render — the
    /// point of a stress test. Oscillates within the synthetic grid's extent.
    private func animatedViewport(at date: Date) -> Viewport {
        let t = date.timeIntervalSinceReferenceDate
        let span = Double(Int(Double(count).squareRoot().rounded(.up))) * 90
        let zoom = 0.5 + 0.18 * sin(t * 0.9)
        let scrollX = -span * (0.25 + 0.2 * sin(t * 0.5))
        let scrollY = -span * (0.25 + 0.2 * cos(t * 0.4))
        return Viewport(scrollX: scrollX, scrollY: scrollY, zoom: zoom)
    }
}

/// Smoothed frame-rate / render-time tracker. A plain reference type (not
/// observed) updated during the `TimelineView` redraw; the timeline re-evaluates
/// the body each frame, so the readout reflects the latest values.
final class FrameMeter {
    private(set) var fps: Double = 0
    private(set) var renderMs: Double = 0
    private var lastDate: Date?

    func tickFrame(_ date: Date) {
        defer { lastDate = date }
        guard let last = lastDate else { return }
        let dt = date.timeIntervalSince(last)
        guard dt > 0 else { return }
        let instant = 1.0 / dt
        fps = fps == 0 ? instant : fps * 0.9 + instant * 0.1
    }

    func recordRender(_ ms: Double) {
        renderMs = renderMs == 0 ? ms : renderMs * 0.9 + ms * 0.1
    }

    func reset() {
        fps = 0
        renderMs = 0
        lastDate = nil
    }
}
