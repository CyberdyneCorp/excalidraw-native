import Foundation
#if canImport(UIKit)
    import UIKit
#endif

/// Thin wrapper over the system pasteboard for the `.excalidraw` JSON payload.
/// No-ops off iOS so the package builds and tests run on the host.
enum Pasteboard {
    static let type = "public.json"

    #if canImport(UIKit)
        static func write(_ data: Data) {
            UIPasteboard.general.setData(data, forPasteboardType: type)
        }

        static func read() -> Data? {
            UIPasteboard.general.data(forPasteboardType: type)
        }
    #else
        static func write(_: Data) {}
        static func read() -> Data? {
            nil
        }
    #endif
}
