import ExcalidrawMetal
import ExcalidrawRender
import SwiftUI

/// Renderer selection (Core Graphics vs Metal) plus the small view-state toggles
/// that live alongside it. Keeping both backends behind `SceneRendering` lets a
/// device without full Metal support fall back to Core Graphics, and lets the
/// two be compared at runtime.
public extension EditorModel {
    enum RendererKind: String, CaseIterable, Sendable {
        case coreGraphics
        case metal

        public var label: String {
            switch self {
            case .coreGraphics: "Core Graphics"
            case .metal: "Metal (GPU)"
            }
        }
    }

    /// Whether a Metal renderer can be created on this device.
    var isMetalAvailable: Bool {
        MetalSceneRenderer.isSupported
    }

    /// Switch the active renderer. Selecting `.metal` on a device without Metal
    /// silently falls back to Core Graphics so rendering never breaks.
    func setRenderer(_ kind: RendererKind) {
        switch kind {
        case .coreGraphics:
            renderer = SceneRenderer()
            rendererKind = .coreGraphics
        case .metal:
            if let metal = MetalSceneRenderer() {
                renderer = metal
                rendererKind = .metal
            } else {
                renderer = SceneRenderer()
                rendererKind = .coreGraphics
            }
        }
        // Drop cached layers so the next frame repaints with the new backend.
        staticLayer.invalidate()
        gestureLayer.invalidate()
        revision += 1
    }

    /// Toggle Metal ↔ Core Graphics (no-op to Metal when unsupported).
    func toggleRenderer() {
        setRenderer(rendererKind == .metal ? .coreGraphics : .metal)
    }

    func toggleTheme() {
        theme = theme == .light ? .dark : .light
        revision += 1
    }

    func toggleZenMode() {
        zenMode.toggle()
    }

    // MARK: Metal direct-to-drawable hybrid

    /// The active renderer as a `MetalSceneRenderer` (for direct-to-drawable
    /// presentation), or `nil` when Core Graphics is active.
    var metalSceneRenderer: MetalSceneRenderer? {
        renderer as? MetalSceneRenderer
    }

    /// Whether the editor canvas should use the Metal hybrid: GPU shapes drawn
    /// straight to a `CAMetalLayer`, with text + selection on a CG overlay.
    var useMetalHybrid: Bool {
        metalSceneRenderer != nil
    }

    /// Draw the editor's Metal-hybrid CG overlay: the elements the GPU does *not*
    /// handle (text, frames, embeddables) plus the interactive overlay (selection
    /// box, handles, snap lines), over a transparent background. The GPU layer
    /// below has already painted the background and all tessellated content.
    func drawMetalOverlay(into ctx: CGContext, size: CGSize) {
        let gpuHandled = Set(
            controller.scene.visibleElements.filter { SceneGeometry.isGPUHandled($0) }.map(\.id)
        )
        cgOverlayRenderer.render(
            controller.scene, in: ctx, viewport: viewport, size: size,
            theme: theme, skipping: gpuHandled, fillBackground: false
        )
        drawOverlay(into: ctx, size: size)
    }
}
