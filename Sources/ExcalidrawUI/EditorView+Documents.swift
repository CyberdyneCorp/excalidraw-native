import ExcalidrawModel
import SwiftUI
import UniformTypeIdentifiers

/// Files-app open/save, recents menu, and autosave wiring for `EditorView`.
extension EditorView {
    /// Content types accepted when opening (a `.excalidraw` JSON, plain JSON, or
    /// an exported PNG with an embedded scene).
    static var openTypes: [UTType] {
        [UTType(filenameExtension: "excalidraw") ?? .json, .json, .png]
    }

    /// Footer menu: open / save / recent documents.
    var documentsMenu: some View {
        Menu {
            Button("Open…", systemImage: "folder") { showDocImporter = true }
            Button("Save…", systemImage: "square.and.arrow.down") { showDocExporter = true }
            if !model.recentDocuments.isEmpty {
                Menu("Recent") {
                    ForEach(model.recentDocuments, id: \.self) { url in
                        Button(url.deletingPathExtension().lastPathComponent) {
                            model.openDocument(at: url)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "folder")
        }
        .accessibilityIdentifier("documents")
    }

    /// Apply the file importer/exporter and autosave lifecycle.
    func documentSupport() -> some ViewModifier {
        DocumentSupport(model: model, showImporter: $showDocImporter, showExporter: $showDocExporter)
    }
}

/// A `.excalidraw` document for `fileExporter`.
struct SceneFileDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "excalidraw") ?? .json, .json]
    }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct DocumentSupport: ViewModifier {
    let model: EditorModel
    @Binding var showImporter: Bool
    @Binding var showExporter: Bool
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $showImporter, allowedContentTypes: EditorView.openTypes) { result in
                if let url = try? result.get() { model.openDocument(at: url) }
            }
            .fileExporter(
                isPresented: $showExporter,
                document: SceneFileDocument(data: model.documentData() ?? Data()),
                contentType: UTType(filenameExtension: "excalidraw") ?? .json,
                defaultFilename: "Drawing"
            ) { result in
                if case let .success(url) = result { DocumentStore.addRecent(url) }
            }
            // Autosave when leaving the foreground; restore on first launch.
            .onChange(of: scenePhase) { _, phase in if phase != .active { model.autosave() } }
            .task { model.restoreAutosaveIfEmpty() }
    }
}
