import ExcalidrawEditor
import ExcalidrawModel
import ExcalidrawRender
import SwiftUI

/// The single-user editor: a toolbar, the drawing canvas with selection
/// overlay, and a properties bar. Pointer input comes from `PointerInputView`
/// (raw `UITouch`) on iOS, with a drag-gesture fallback elsewhere.
public struct EditorView: View {
    @StateObject private var model: EditorModel
    @State private var exported = false

    private let tools: [(Tool, String)] = [
        (.selection, "cursorarrow"),
        (.rectangle, "rectangle"),
        (.diamond, "diamond"),
        (.ellipse, "circle"),
        (.line, "line.diagonal"),
    ]
    private let palette = ["#1e1e1e", "#e03131", "#2f9e44", "#1971c2", "#f08c00"]

    public init(scene: ExcalidrawModel.Scene = ExcalidrawModel.Scene(), viewport: Viewport = Viewport()) {
        _model = StateObject(wrappedValue: EditorModel(scene: scene, viewport: viewport))
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            canvas
            propertiesBar
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            ForEach(tools, id: \.0) { tool, icon in
                Button { model.select(tool: tool) } label: {
                    Image(systemName: icon)
                        .frame(width: 32, height: 32)
                        .background(model.activeTool == tool ? Color.accentColor.opacity(0.25) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .accessibilityIdentifier("tool-\(tool.rawValue)")
            }
            Spacer()
            Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .accessibilityIdentifier("undo")
            Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .accessibilityIdentifier("redo")
            Button { model.deleteSelected() } label: { Image(systemName: "trash") }
                .accessibilityIdentifier("delete")
            Button(action: doExport) { Image(systemName: "square.and.arrow.up") }
                .accessibilityIdentifier("export")
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.thinMaterial)
    }

    private var canvas: some View {
        Canvas { context, size in
            _ = model.revision // redraw when the model changes
            context.withCGContext { cg in
                model.renderer.render(model.controller.scene, in: cg, viewport: model.viewport, size: size)
                let handles = model.controller.transformHandles()
                let squares = handles.filter { $0.key != .rotation }.map(\.value)
                InteractiveRenderer.render(
                    selectionBounds: model.controller.selectionBounds,
                    handles: squares,
                    rotationHandle: handles[.rotation],
                    selectionRect: model.controller.selectionRect,
                    in: cg, viewport: model.viewport
                )
            }
        }
        .accessibilityIdentifier("excalidraw-canvas")
        .overlay(inputLayer)
        .background(Color.white)
    }

    @ViewBuilder
    private var inputLayer: some View {
        #if canImport(UIKit)
        PointerInputView(model: model)
        #else
        Color.clear.contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if v.translation == .zero { model.pointer(.down, at: v.startLocation) }
                        model.pointer(.move, at: v.location)
                    }
                    .onEnded { v in model.pointer(.up, at: v.location) }
            )
        #endif
    }

    private var propertiesBar: some View {
        HStack(spacing: 12) {
            ForEach(palette, id: \.self) { color in
                Button { model.setStrokeColor(color) } label: {
                    Circle().fill(Color(hex: color)).frame(width: 22, height: 22)
                        .overlay(Circle().stroke(model.strokeColor == color ? Color.accentColor : .gray.opacity(0.3),
                                                 lineWidth: model.strokeColor == color ? 2 : 1))
                }
                .accessibilityIdentifier("stroke-\(color)")
            }
            Spacer()
            Stepper("Width \(Int(model.strokeWidth))", value: Binding(
                get: { model.strokeWidth },
                set: { model.setStrokeWidth($0) }
            ), in: 1...20)
            .fixedSize()
            if exported {
                Text("Exported").foregroundStyle(.secondary).accessibilityIdentifier("exported-confirmation")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.thinMaterial)
    }

    private func doExport() {
        guard let data = model.exportPNG() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("excalidraw-export.png")
        try? data.write(to: url)
        exported = true
    }
}

extension Color {
    /// Lightweight hex → Color for the palette swatches.
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
