#if canImport(UIKit)
    import SwiftUI
    import WebKit

    /// A `WKWebView` that loads an allow-listed embed URL, used to render live
    /// embeddables over the canvas. `interactive` gates touch handling so the
    /// canvas can still select/move the element (passive under the selection
    /// tool, live otherwise).
    struct WebEmbedView: UIViewRepresentable {
        let url: URL
        let interactive: Bool

        func makeUIView(context _: Context) -> WKWebView {
            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            let view = WKWebView(frame: .zero, configuration: config)
            view.scrollView.isScrollEnabled = false
            view.isOpaque = false
            view.load(URLRequest(url: url))
            return view
        }

        func updateUIView(_ view: WKWebView, context _: Context) {
            if view.url != url { view.load(URLRequest(url: url)) }
            view.isUserInteractionEnabled = interactive
        }
    }
#endif
