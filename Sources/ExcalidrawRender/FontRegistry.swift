import CoreGraphics
import CoreText
import ExcalidrawModel
import Foundation

/// Bundled-font loading + family mapping. Registers any font files dropped into
/// the app bundle's `Fonts/` folder (or the package resources) and, per
/// Excalidraw font family, prefers the matching bundled font when present,
/// otherwise falls back to a system handwriting/sans/mono face.
///
/// The infrastructure is wired so that adding the licensed font files
/// (Excalifont, Comic Shanns, etc.) and their PostScript names below makes them
/// "just work"; until then text uses the system fallbacks.
public enum FontRegistry {
    /// Excalidraw family → preferred PostScript name (used if registered) and a
    /// system fallback. Fill in the PostScript names when the real fonts ship.
    private static let mapping: [Int: (preferred: String?, fallback: String)] = [
        FontFamily.excalifont: ("Excalifont-Regular", "Bradley Hand"),
        FontFamily.virgil: ("Virgil", "Bradley Hand"),
        FontFamily.nunito: ("Nunito-Regular", "Bradley Hand"),
        FontFamily.lilitaOne: ("LilitaOne", "Bradley Hand"),
        FontFamily.comicShanns: ("ComicShanns", "Menlo"),
        FontFamily.cascadia: ("CascadiaCode-Regular", "Menlo"),
        FontFamily.helvetica: (nil, "Helvetica"),
        FontFamily.liberationSans: ("LiberationSans", "Helvetica"),
        FontFamily.assistant: ("Assistant-Regular", "Helvetica")
    ]

    private static var registered = false
    /// PostScript names that are actually available (bundled + registered, or a
    /// system font by that name).
    private static var availableNames: Set<String> = []

    /// Register bundled fonts once. Idempotent and safe to call at launch.
    public static func registerBundledFonts() {
        guard !registered else { return }
        registered = true
        for url in bundledFontURLs() {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// The font name to use for `family`: the preferred bundled face when it's
    /// available, otherwise the system fallback.
    public static func fontName(for family: Int) -> String {
        registerBundledFonts()
        let entry = mapping[family] ?? (nil, "Bradley Hand")
        if let preferred = entry.preferred, isAvailable(preferred) { return preferred }
        return entry.fallback
    }

    /// Whether a font with `postScriptName` can be instantiated (registered
    /// bundle font or a real system font — not a silent substitution).
    private static func isAvailable(_ postScriptName: String) -> Bool {
        if availableNames.contains(postScriptName) { return true }
        let font = CTFontCreateWithName(postScriptName as CFString, 12, nil)
        let resolved = CTFontCopyPostScriptName(font) as String
        let available = resolved.caseInsensitiveCompare(postScriptName) == .orderedSame
        if available { availableNames.insert(postScriptName) }
        return available
    }

    private static func bundledFontURLs() -> [URL] {
        var urls: [URL] = []
        let extensions = ["ttf", "otf", "woff2"]
        // App bundle `Fonts/` and the bundle root.
        for ext in extensions {
            urls += Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") ?? []
            urls += Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
        }
        return urls
    }
}
