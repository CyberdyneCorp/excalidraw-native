import ExcalidrawEditor
import ExcalidrawModel
import ExcalidrawRender
import PhotosUI
import SwiftUI

/// The single-user editor: a tool/action toolbar, the drawing canvas with
/// selection overlay and on-canvas text editing, and a properties bar. Pointer
/// input comes from `PointerInputView` (raw `UITouch`) on iOS.
public struct EditorView: View {
    @StateObject private var model: EditorModel
    @State private var exported = false
    @State private var photoItem: PhotosPickerItem?

    private let tools: [(Tool, String)] = [
        (.selection, "cursorarrow"), (.rectangle, "rectangle"), (.diamond, "diamond"),
        (.ellipse, "circle"), (.arrow, "arrow.up.right"), (.line, "line.diagonal"),
        (.freedraw, "scribble"), (.text, "textformat"), (.eraser, "eraser"), (.hand, "hand.draw"),
    ]
    private let palette = ["#1e1e1e", "#e03131", "#2f9e44", "#1971c2", "#f08c00"]
    private let fills = ["transparent", "#ffc9c9", "#b2f2bb", "#a5d8ff", "#ffec99"]

    public init(scene: ExcalidrawModel.Scene = ExcalidrawModel.Scene(), viewport: Viewport = Viewport()) {
        _model = StateObject(wrappedValue: EditorModel(scene: scene, viewport: viewport))
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            canvas
            propertiesBar
        }
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tools, id: \.0) { tool, icon in
                        toolButton(tool, icon)
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo")
                    }.accessibilityIdentifier("tool-image")
                    actionButton("doc.on.doc", "duplicate") { model.duplicate() }
                    actionButton("square.3.layers.3d.top.filled", "front") { model.bringToFront() }
                    actionButton("trash", "delete") { model.deleteSelected() }
                }
                .padding(.leading, 12)
            }
            // Pinned actions, always reachable.
            Divider().frame(height: 24)
            actionButton("arrow.uturn.backward", "undo") { model.undo() }
            actionButton("arrow.uturn.forward", "redo") { model.redo() }
            actionButton("square.and.arrow.up", "export", action: doExport)
                .padding(.trailing, 12)
        }
        .frame(height: 44)
        .background(.thinMaterial)
    }

    private func toolButton(_ tool: Tool, _ icon: String) -> some View {
        Button { model.select(tool: tool) } label: {
            Image(systemName: icon)
                .frame(width: 30, height: 30)
                .background(model.activeTool == tool ? Color.accentColor.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityIdentifier("tool-\(tool.rawValue)")
    }

    private func actionButton(_ icon: String, _ id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon) }.accessibilityIdentifier(id)
    }

    private var canvas: some View {
        Canvas { context, size in
            _ = model.revision
            context.withCGContext { cg in
                model.renderer.render(model.controller.scene, in: cg, viewport: model.viewport, size: size)
                let handles = model.controller.transformHandles()
                InteractiveRenderer.render(
                    selectionBounds: model.controller.selectionBounds,
                    handles: handles.filter { $0.key != .rotation }.map(\.value),
                    rotationHandle: handles[.rotation],
                    selectionRect: model.controller.selectionRect,
                    in: cg, viewport: model.viewport
                )
            }
        }
        .accessibilityIdentifier("excalidraw-canvas")
        .overlay(inputLayer)
        .overlay(textEditor)
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

    @ViewBuilder
    private var textEditor: some View {
        if model.editingTextID != nil {
            TextField("Text", text: $model.editingText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .position(x: model.editingTextOrigin.x + 100, y: model.editingTextOrigin.y + 20)
                .accessibilityIdentifier("text-editor")
                .onSubmit { model.commitText() }
                .submitLabel(.done)
                .overlay(alignment: .topTrailing) {
                    Button("Done") { model.commitText() }
                        .accessibilityIdentifier("text-done")
                        .padding(4)
                }
        }
    }

    private var propertiesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                swatches(palette, selected: model.strokeColor, id: "stroke") { model.setStrokeColor($0) }
                Divider().frame(height: 24)
                swatches(fills, selected: model.backgroundColor, id: "bg") { model.setBackgroundColor($0) }
                Divider().frame(height: 24)
                Stepper("W \(Int(model.strokeWidth))", value: Binding(
                    get: { model.strokeWidth }, set: { model.setStrokeWidth($0) }
                ), in: 1...20).fixedSize()
                if exported {
                    Text("Exported").foregroundStyle(.secondary).accessibilityIdentifier("exported-confirmation")
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 44)
        .background(.thinMaterial)
    }

    private func swatches(
        _ colors: [String], selected: String, id: String, action: @escaping (String) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(colors, id: \.self) { color in
                Button { action(color) } label: {
                    Circle().fill(color == "transparent" ? Color.white : Color(hex: color))
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(selected == color ? Color.accentColor : .gray.opacity(0.3),
                                                 lineWidth: selected == color ? 2 : 1))
                }
                .accessibilityIdentifier("\(id)-\(color)")
            }
        }
    }

    private func doExport() {
        guard let data = model.exportPNG() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("excalidraw-export.png")
        try? data.write(to: url)
        exported = true
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                model.insertImage(data: data, mimeType: "image/png", viewSize: CGSize(width: 400, height: 400))
            }
        }
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
