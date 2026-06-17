import ExcalidrawRender
import ExcalidrawUI
import SwiftUI

@main
struct ExcalidrawApp: App {
    init() {
        // Register any bundled Excalidraw fonts so text uses them when present.
        FontRegistry.registerBundledFonts()
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            EditorView()
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
