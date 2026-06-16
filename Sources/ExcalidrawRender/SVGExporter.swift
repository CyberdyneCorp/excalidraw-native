import ExcalidrawGeometry
import ExcalidrawMath
import ExcalidrawModel
import Foundation
import FreehandKit
import RoughKit

/// Exports a scene to an SVG string, fitting content with padding. Ports the
/// intent of `staticSvgScene.ts`. Shapes use the rough.js drawable paths;
/// freedraw uses the FreehandKit outline; text and images are emitted as
/// `<text>` / `<image>`.
public enum SVGExporter {
    public static func svg(_ scene: Scene, padding: Double = 16) -> String {
        guard let bounds = ElementGeometry.commonBounds(scene.visibleElements) else {
            return emptySVG()
        }
        let width = bounds.width + 2 * padding
        let height = bounds.height + 2 * padding
        let offsetX = padding - bounds.minX
        let offsetY = padding - bounds.minY
        let background = scene.appState.viewBackgroundColor ?? "#ffffff"

        var body = ""
        body += #"<rect width="\#(fmt(width))" height="\#(fmt(height))" fill="\#(escape(background))"/>"# + "\n"
        for element in scene.visibleElements {
            body += group(element) + "\n"
        }

        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(fmt(width))" height="\(fmt(height))" \
        viewBox="0 0 \(fmt(width)) \(fmt(height))">
        <g transform="translate(\(fmt(offsetX)) \(fmt(offsetY)))">
        \(body)</g>
        </svg>
        """
    }

    // MARK: Per-element

    private static func group(_ element: ExcalidrawElement) -> String {
        let base = element.base
        let cx = base.width / 2, cy = base.height / 2
        var transform = "translate(\(fmt(base.x)) \(fmt(base.y)))"
        if base.angle != 0 {
            transform += " rotate(\(fmt(base.angle * 180 / .pi)) \(fmt(cx)) \(fmt(cy)))"
        }
        let opacity = base.opacity / 100
        let content = elementBody(element)
        return #"<g transform="\#(transform)" opacity="\#(fmt(opacity))">\#(content)</g>"#
    }

    private static func elementBody(_ element: ExcalidrawElement) -> String {
        let base = element.base
        switch element.kind {
        case let .text(text):
            return textBody(text, base: base)
        case let .image(image):
            return imageBody(image, base: base)
        case let .freedraw(props):
            return freedrawBody(props, base: base)
        default:
            guard let drawable = ElementDrawable.drawable(for: element) else { return "" }
            return drawableBody(drawable, base: base)
        }
    }

    private static func drawableBody(_ drawable: Drawable, base: BaseProperties) -> String {
        let stroke = base.strokeColor
        let fill = drawable.options.fill
        var out = ""
        for set in drawable.sets {
            let d = pathData(set.ops)
            switch set.type {
            case .fillPath:
                if let fill { out += #"<path d="\#(d)" fill="\#(escape(fill))" stroke="none"/>"# }
            case .fillSketch:
                if let fill {
                    let weight = drawable.options.fillWeight > 0 ? drawable.options.fillWeight : base.strokeWidth / 2
                    out += #"<path d="\#(d)" fill="none" stroke="\#(escape(fill))" stroke-width="\#(fmt(weight))"/>"#
                }
            case .path:
                let dash = drawable.options.strokeLineDash
                    .map { #" stroke-dasharray="\#($0.map(fmt).joined(separator: ","))""# } ?? ""
                let attrs = #"fill="none" stroke="\#(escape(stroke))" "#
                    + #"stroke-width="\#(fmt(base.strokeWidth))" stroke-linecap="round""#
                out += #"<path d="\#(d)" \#(attrs)\#(dash)/>"#
            }
        }
        return out
    }

    private static func freedrawBody(_ props: FreedrawProperties, base: BaseProperties) -> String {
        let inputs = props.points.enumerated().map { i, p in
            FreehandPoint(x: p.x, y: p.y, pressure: i < props.pressures.count ? props.pressures[i] : 0.5)
        }
        let options = FreehandOptions(strokeWidth: base.strokeWidth, simulatePressure: props.simulatePressure)
        let outline = FreehandKit.strokeOutline(inputs, options: options)
        guard let first = outline.first, outline.count > 2 else { return "" }
        var d = "M \(fmt(first.x)) \(fmt(first.y)) "
        for p in outline.dropFirst() {
            d += "L \(fmt(p.x)) \(fmt(p.y)) "
        }
        d += "Z"
        return #"<path d="\#(d)" fill="\#(escape(base.strokeColor))" stroke="none"/>"#
    }

    private static func textBody(_ text: TextProperties, base: BaseProperties) -> String {
        let lines = text.text.components(separatedBy: "\n")
        let lineHeight = text.fontSize * text.lineHeight
        var out = ""
        for (i, lineText) in lines.enumerated() {
            let y = lineHeight * Double(i) + text.fontSize * 0.8
            let attrs = #"x="0" y="\#(fmt(y))" font-size="\#(fmt(text.fontSize))" fill="\#(escape(base.strokeColor))""#
            out += #"<text \#(attrs)>\#(escape(lineText))</text>"#
        }
        return out
    }

    private static func imageBody(_ image: ImageProperties, base: BaseProperties) -> String {
        // Note: width/height in user space; the data URL (if any) is set by the host.
        let href = image.fileId ?? ""
        return #"<image width="\#(fmt(base.width))" height="\#(fmt(base.height))" data-file-id="\#(escape(href))"/>"#
    }

    // MARK: Helpers

    private static func pathData(_ ops: [PathOp]) -> String {
        var d = ""
        for op in ops {
            switch op {
            case let .move(p): d += "M \(fmt(p.x)) \(fmt(p.y)) "
            case let .lineTo(p): d += "L \(fmt(p.x)) \(fmt(p.y)) "
            case let .bcurveTo(c1, c2, e):
                d += "C \(fmt(c1.x)) \(fmt(c1.y)) \(fmt(c2.x)) \(fmt(c2.y)) \(fmt(e.x)) \(fmt(e.y)) "
            }
        }
        return d.trimmingCharacters(in: .whitespaces)
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func emptySVG() -> String {
        #"<svg xmlns="http://www.w3.org/2000/svg" width="0" height="0" viewBox="0 0 0 0"></svg>"#
    }
}
