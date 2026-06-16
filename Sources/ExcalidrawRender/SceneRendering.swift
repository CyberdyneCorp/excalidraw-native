import CoreGraphics
import ExcalidrawGeometry
import ExcalidrawModel

/// A swappable scene renderer. `SceneRenderer` (Core Graphics) is the default;
/// a Metal-backed renderer can be substituted at runtime, with this protocol
/// keeping the editor/canvas renderer-agnostic. Both must produce equivalent
/// output so a device can fall back to Core Graphics (or compare the two).
public protocol SceneRendering: AnyObject {
    /// Render `scene` into `ctx`. `skipping` omits elements (for the layered
    /// static/dynamic split); `fillBackground: false` composites onto an
    /// already-painted image (the dynamic overlay pass); `clip` limits drawing
    /// to a scene-space rectangle.
    func render(
        _ scene: Scene, in ctx: CGContext, viewport: Viewport, size: CGSize,
        theme: Theme, clip: BoundingBox?, skipping: Set<String>, fillBackground: Bool
    )
}

public extension SceneRendering {
    /// Convenience matching the common call sites (no clip, optional skip/bg).
    func render(
        _ scene: Scene, in ctx: CGContext, viewport: Viewport, size: CGSize,
        theme: Theme = .light, skipping: Set<String> = [], fillBackground: Bool = true
    ) {
        render(
            scene, in: ctx, viewport: viewport, size: size, theme: theme,
            clip: nil, skipping: skipping, fillBackground: fillBackground
        )
    }
}
