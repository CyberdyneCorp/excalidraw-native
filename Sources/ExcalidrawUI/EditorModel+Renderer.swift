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
}
