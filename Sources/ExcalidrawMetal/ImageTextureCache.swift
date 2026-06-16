#if canImport(Metal)
    import CoreGraphics
    import ExcalidrawModel
    import ExcalidrawRender
    import Foundation
    import Metal

    /// Decodes image `BinaryFileData` into `MTLTexture`s, cached by file id, so an
    /// image is decoded and uploaded to the GPU once and then drawn as a textured
    /// quad each frame. Mirrors `ImageDecoder` (which caches the `CGImage`); this
    /// adds the GPU upload on top.
    final class ImageTextureCache {
        private let device: MTLDevice
        private let decoder = ImageDecoder()
        private var textures: [String: MTLTexture] = [:]

        init(device: MTLDevice) {
            self.device = device
        }

        /// The texture for `fileId`, decoding + uploading on first use. Returns
        /// `nil` if the data URL can't be decoded.
        func texture(fileId: String, dataURL: String) -> MTLTexture? {
            if let texture = textures[fileId] { return texture }
            guard let cgImage = decoder.image(fileId: fileId, dataURL: dataURL),
                  let texture = upload(cgImage) else { return nil }
            textures[fileId] = texture
            return texture
        }

        func removeAll() {
            textures.removeAll()
        }

        /// Draw the `CGImage` into a tightly-packed RGBA8 (premultiplied) buffer
        /// and upload it as a `.rgba8Unorm` texture. Drawing through a context
        /// normalizes arbitrary source formats to what the sampler expects.
        private func upload(_ cgImage: CGImage) -> MTLTexture? {
            let width = cgImage.width, height = cgImage.height
            guard width > 0, height > 0 else { return nil }
            let bytesPerRow = width * 4
            var data = [UInt8](repeating: 0, count: bytesPerRow * height)
            guard let ctx = CGContext(
                data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            // A bitmap context is bottom-up; flip so the texture's first row is
            // the top of the image (UV (0,0) = visual top-left, drawn upright).
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false
            )
            descriptor.usage = .shaderRead
            descriptor.storageMode = .shared
            guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
            data.withUnsafeBytes { raw in
                texture.replace(
                    region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                    withBytes: raw.baseAddress!, bytesPerRow: bytesPerRow
                )
            }
            return texture
        }
    }
#endif
