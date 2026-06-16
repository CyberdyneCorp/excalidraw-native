import CoreGraphics
import Foundation

public enum Theme: String, Sendable {
    case light
    case dark
}

/// Excalidraw's dark mode is a canvas filter `invert(100%) hue-rotate(180deg)`.
/// Applying it per colour (rather than to the whole bitmap) keeps element hues
/// recognisable while swapping light/dark.
public enum ThemeFilter {
    public static func apply(_ color: CGColor, theme: Theme) -> CGColor {
        guard theme == .dark, let c = color.components, c.count >= 3 else { return color }
        let alpha = c.count >= 4 ? c[3] : 1

        // invert(100%)
        let ir = 1 - c[0], ig = 1 - c[1], ib = 1 - c[2]

        // hue-rotate(180deg) — the CSS hue-rotate matrix evaluated at 180°.
        let r = clamp(-0.574 * ir + 1.430 * ig + 0.144 * ib)
        let g = clamp(0.426 * ir + 0.430 * ig + 0.144 * ib)
        let b = clamp(0.426 * ir + 1.430 * ig - 0.856 * ib)
        return CGColor(red: r, green: g, blue: b, alpha: alpha)
    }

    private static func clamp(_ v: CGFloat) -> CGFloat {
        Swift.min(1, Swift.max(0, v))
    }
}
