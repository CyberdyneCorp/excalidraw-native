#if canImport(UIKit)
    import ExcalidrawMetal
    import QuartzCore
    import SwiftUI
    import UIKit

    /// The editor's direct-to-drawable Metal canvas: a `CAMetalLayer`-backed view
    /// that renders the live scene at the current viewport straight into the
    /// layer's drawable (GPU shapes / freedraw / dashed strokes / images), with no
    /// read-back. Text and the interactive overlay are drawn on a Core Graphics
    /// layer above this (so text stays crisp at any zoom). Re-renders on demand
    /// whenever SwiftUI updates the view (a `revision` / viewport change).
    struct EditorMetalCanvas: UIViewRepresentable {
        let model: EditorModel

        func makeUIView(context _: Context) -> EditorMetalView {
            let view = EditorMetalView()
            view.model = model
            return view
        }

        func updateUIView(_ view: EditorMetalView, context _: Context) {
            view.model = model
            view.render()
        }
    }

    final class EditorMetalView: UIView {
        // `layerClass` must be `class` (UIView's is); the cast in `metalLayer`
        // relies on this override.
        // swiftlint:disable:next static_over_final_class
        override class var layerClass: AnyClass {
            CAMetalLayer.self
        }

        weak var model: EditorModel?

        private var metalLayer: CAMetalLayer {
            // Guaranteed by the `layerClass` override.
            // swiftlint:disable:next force_cast
            layer as! CAMetalLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            metalLayer.device = MTLCreateSystemDefaultDevice()
            metalLayer.pixelFormat = .bgra8Unorm
            metalLayer.framebufferOnly = true
            isOpaque = true
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) unavailable")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            metalLayer.drawableSize = CGSize(
                width: bounds.width * contentScaleFactor,
                height: bounds.height * contentScaleFactor
            )
            render()
        }

        @MainActor
        func render() {
            guard let model, let renderer = model.metalSceneRenderer,
                  bounds.width > 0, bounds.height > 0,
                  let drawable = metalLayer.nextDrawable() else { return }
            renderer.renderToDrawable(
                drawable, scene: model.controller.scene,
                viewport: model.viewport, size: bounds.size, theme: model.theme
            )
        }
    }
#endif
