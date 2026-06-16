import CoreGraphics
import Foundation

/// Parses Excalidraw colour strings (`"#rgb"`, `"#rrggbb"`, `"#rrggbbaa"`,
/// `"transparent"`) into `CGColor`s in device RGB.
public enum ColorParser {
    public static func cgColor(_ string: String) -> CGColor? {
        let value = string.trimmingCharacters(in: .whitespaces).lowercased()
        if value == "transparent" || value.isEmpty {
            return CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
        guard value.hasPrefix("#") else { return namedColor(value) }
        let hex = String(value.dropFirst())

        func component(_ substr: Substring) -> CGFloat {
            CGFloat(Int(substr, radix: 16) ?? 0) / 255
        }

        switch hex.count {
        case 3: // #rgb
            let chars = Array(hex)
            return CGColor(
                red: component(Substring(String(repeating: chars[0], count: 2))),
                green: component(Substring(String(repeating: chars[1], count: 2))),
                blue: component(Substring(String(repeating: chars[2], count: 2))),
                alpha: 1
            )
        case 6: // #rrggbb
            let s = Array(hex)
            return CGColor(
                red: component(Substring(String(s[0 ... 1]))),
                green: component(Substring(String(s[2 ... 3]))),
                blue: component(Substring(String(s[4 ... 5]))),
                alpha: 1
            )
        case 8: // #rrggbbaa
            let s = Array(hex)
            return CGColor(
                red: component(Substring(String(s[0 ... 1]))),
                green: component(Substring(String(s[2 ... 3]))),
                blue: component(Substring(String(s[4 ... 5]))),
                alpha: component(Substring(String(s[6 ... 7])))
            )
        default:
            return nil
        }
    }

    public static func isTransparent(_ string: String) -> Bool {
        let value = string.trimmingCharacters(in: .whitespaces).lowercased()
        if value == "transparent" || value.isEmpty { return true }
        return value.count == 9 && value.hasPrefix("#") && value.hasSuffix("00")
    }

    private static func namedColor(_ value: String) -> CGColor? {
        switch value {
        case "white": CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        case "black": CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        default: nil
        }
    }
}
