import CoreGraphics
import Foundation
import ImageIO

/// Decodes `BinaryFileData` data-URLs into `CGImage`s, cached by file id.
public final class ImageDecoder {
    private var cache: [String: CGImage] = [:]

    public init() {}

    /// Decode (and cache) the image for `fileId` from its `dataURL`.
    public func image(fileId: String, dataURL: String) -> CGImage? {
        if let cached = cache[fileId] { return cached }
        guard let image = Self.decode(dataURL: dataURL) else { return nil }
        cache[fileId] = image
        return image
    }

    public static func decode(dataURL: String) -> CGImage? {
        // data:[<mime>][;base64],<payload>
        guard let commaIndex = dataURL.firstIndex(of: ",") else { return nil }
        let payload = String(dataURL[dataURL.index(after: commaIndex)...])
        guard dataURL.hasPrefix("data:"), dataURL[..<commaIndex].contains("base64"),
              let data = Data(base64Encoded: payload) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
