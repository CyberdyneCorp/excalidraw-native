import SwiftUI

extension EditorView {
    /// A tiny accessibility surface so the live-collab UI test can read the
    /// shared-scene element count + peer count. Only present while collaborating.
    @ViewBuilder var collabStatus: some View {
        if model.collab != nil {
            VStack(spacing: 0) {
                Text("\(model.controller.scene.visibleElements.count)")
                    .accessibilityIdentifier("collab-element-count")
                Text("\(model.remotePeers.count)")
                    .accessibilityIdentifier("collab-peer-count")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(4)
        }
    }
}
