#if canImport(UIKit)
    import ExcalidrawMetal
    import ExcalidrawModel
    import ExcalidrawRender
    import QuartzCore
    import SwiftUI
    import UIKit

    /// Direct-to-drawable Metal canvas: a `CAMetalLayer`-backed view that renders
    /// the scene's GPU geometry straight into the layer's drawable and presents it
    /// — no off-screen texture read-back, no `CGContext`. A `CADisplayLink` drives
    /// a continuously animated (pan/zoom) frame so the live benchmark can show the
    /// true on-screen GPU pipeline and its frame rate. Non-tessellated content
    /// (text/images) is not drawn here; this is the GPU-only path used for the
    /// benchmark's synthetic shape/freedraw scenes.
    struct MetalCanvasView: UIViewRepresentable {
        let scene: ExcalidrawModel.Scene
        let theme: Theme
        let count: Int
        let meter: FrameMeter

        func makeUIView(context _: Context) -> MetalDrawableView {
            let view = MetalDrawableView()
            view.meter = meter
            view.configure(scene: scene, theme: theme, count: count)
            return view
        }

        func updateUIView(_ view: MetalDrawableView, context _: Context) {
            view.meter = meter
            view.configure(scene: scene, theme: theme, count: count)
        }

        static func dismantleUIView(_ view: MetalDrawableView, coordinator _: ()) {
            view.stop()
        }
    }

    final class MetalDrawableView: UIView {
        // UIView's `layerClass` is a `class` property, so the override must be
        // `class` (not `static`); this makes the view's backing layer a
        // `CAMetalLayer`, which the force-cast in `metalLayer` then relies on.
        // swiftlint:disable:next static_over_final_class
        override class var layerClass: AnyClass {
            CAMetalLayer.self
        }

        var meter: FrameMeter?
        private let renderer = MetalSceneRenderer()
        private var displayLink: CADisplayLink?
        private var scene = ExcalidrawModel.Scene()
        private var theme: Theme = .light
        private var count = 500
        private var startTime: CFTimeInterval = 0

        private var metalLayer: CAMetalLayer {
            // Guaranteed by the `layerClass` override above.
            // swiftlint:disable:next force_cast
            layer as! CAMetalLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            setUp()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) unavailable")
        }

        private func setUp() {
            metalLayer.device = MTLCreateSystemDefaultDevice()
            metalLayer.pixelFormat = .bgra8Unorm
            metalLayer.framebufferOnly = true
            isOpaque = true
            startTime = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func configure(scene: ExcalidrawModel.Scene, theme: Theme, count: Int) {
            self.scene = scene
            self.theme = theme
            self.count = count
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            metalLayer.drawableSize = CGSize(
                width: bounds.width * contentScaleFactor,
                height: bounds.height * contentScaleFactor
            )
        }

        @objc private func tick(_ link: CADisplayLink) {
            guard let renderer, bounds.width > 0, bounds.height > 0,
                  let drawable = metalLayer.nextDrawable() else { return }
            let elapsed = CACurrentMediaTime() - startTime
            let viewport = LiveBenchmarkView.animatedViewport(at: elapsed, count: count)
            let start = DispatchTime.now().uptimeNanoseconds
            renderer.renderToDrawable(drawable, scene: scene, viewport: viewport, size: bounds.size, theme: theme)
            meter?.recordRender(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
            meter?.tickFrame(at: link.timestamp)
        }
    }
#endif
