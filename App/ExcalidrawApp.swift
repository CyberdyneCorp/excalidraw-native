import ExcalidrawUI
import SwiftUI

@main
struct ExcalidrawApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            EditorView()
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
