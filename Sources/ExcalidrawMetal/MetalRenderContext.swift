#if canImport(Metal)
    import CoreGraphics
    import Foundation
    import Metal

    /// Owns the Metal device, command queue and render pipeline, and rasterizes a
    /// batch of colored triangles into an off-screen `CGImage`.
    ///
    /// Returns `nil` from `init` whenever Metal (device, queue, or shader compile)
    /// is unavailable, so callers fall back to Core Graphics. The pipeline is built
    /// once from runtime-compiled shader source; each `image(...)` call allocates
    /// transient textures sized to the request and 4× multisamples for crisp,
    /// resolution-independent edges (the whole point of the GPU path under zoom).
    final class MetalRenderContext {
        /// Scene→clip affine, evaluated per vertex in the shader: `clip = (a*p + b)`.
        struct Transform {
            var ax: Float
            var bx: Float
            var cy: Float
            var dy: Float
        }

        private let device: MTLDevice
        private let queue: MTLCommandQueue
        private let pipeline: MTLRenderPipelineState
        private let sampleCount = 4
        private let pixelFormat: MTLPixelFormat = .rgba8Unorm

        init?() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let queue = device.makeCommandQueue() else { return nil }
            guard let pipeline = Self.makePipeline(device: device, sampleCount: 4, pixelFormat: .rgba8Unorm) else {
                return nil
            }
            self.device = device
            self.queue = queue
            self.pipeline = pipeline
        }

        /// Whether a usable Metal device exists on this host without building a
        /// whole context (used by availability checks / fallback decisions).
        static var isSupported: Bool {
            MTLCreateSystemDefaultDevice() != nil
        }

        private static func makePipeline(
            device: MTLDevice, sampleCount: Int, pixelFormat: MTLPixelFormat
        ) -> MTLRenderPipelineState? {
            let library: MTLLibrary
            do {
                library = try device.makeLibrary(source: shaderSource, options: nil)
            } catch {
                return nil
            }
            guard let vertexFn = library.makeFunction(name: "scene_vertex"),
                  let fragmentFn = library.makeFunction(name: "scene_fragment") else { return nil }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFn
            descriptor.fragmentFunction = fragmentFn
            descriptor.rasterSampleCount = sampleCount
            let attachment = descriptor.colorAttachments[0]!
            attachment.pixelFormat = pixelFormat
            // The vertex shader emits premultiplied color, so source-over uses a
            // source factor of `.one` (alpha is already folded into rgb).
            attachment.isBlendingEnabled = true
            attachment.rgbBlendOperation = .add
            attachment.alphaBlendOperation = .add
            attachment.sourceRGBBlendFactor = .one
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try? device.makeRenderPipelineState(descriptor: descriptor)
        }

        /// Rasterize `vertices` (interleaved `[x, y, r, g, b, a]`) into a
        /// `pixelWidth × pixelHeight` RGBA image. Returns `nil` on any GPU failure.
        func image(vertices: [Float], transform: Transform, pixelWidth: Int, pixelHeight: Int) -> CGImage? {
            guard pixelWidth > 0, pixelHeight > 0, vertices.count >= 18 else { return nil }
            let vertexCount = vertices.count / 6

            guard let msaaTexture = makeTexture(width: pixelWidth, height: pixelHeight, multisampled: true),
                  let resolveTexture = makeTexture(width: pixelWidth, height: pixelHeight, multisampled: false),
                  let vertexBuffer = device.makeBuffer(
                      bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: .storageModeShared
                  ) else { return nil }

            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = msaaTexture
            pass.colorAttachments[0].resolveTexture = resolveTexture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .multisampleResolve
            pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

            guard let commandBuffer = queue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }

            var transform = transform
            encoder.setRenderPipelineState(pipeline)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&transform, length: MemoryLayout<Transform>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()

            return makeImage(from: resolveTexture, width: pixelWidth, height: pixelHeight)
        }

        private func makeTexture(width: Int, height: Int, multisampled: Bool) -> MTLTexture? {
            let descriptor = MTLTextureDescriptor()
            descriptor.pixelFormat = pixelFormat
            descriptor.width = width
            descriptor.height = height
            descriptor.usage = [.renderTarget]
            if multisampled {
                descriptor.textureType = .type2DMultisample
                descriptor.sampleCount = sampleCount
                descriptor.storageMode = .private
            } else {
                descriptor.textureType = .type2D
                descriptor.usage = [.renderTarget, .shaderRead]
                descriptor.storageMode = .shared
            }
            return device.makeTexture(descriptor: descriptor)
        }

        /// Read the resolved RGBA texture back into a `CGImage` (row 0 = top).
        private func makeImage(from texture: MTLTexture, width: Int, height: Int) -> CGImage? {
            let bytesPerRow = width * 4
            var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
            let region = MTLRegionMake2D(0, 0, width, height)
            bytes.withUnsafeMutableBytes { raw in
                texture.getBytes(raw.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
            }
            guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            return CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo, provider: provider, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent
            )
        }
    }

    /// Runtime-compiled Metal shaders: project scene coordinates to clip space and
    /// pass the per-vertex color straight through.
    private let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float2 position [[attribute(0)]];
        float4 color [[attribute(1)]];
    };

    struct Transform {
        float ax;
        float bx;
        float cy;
        float dy;
    };

    struct VertexOut {
        float4 position [[position]];
        float4 color;
    };

    vertex VertexOut scene_vertex(uint vid [[vertex_id]],
                                  const device float *verts [[buffer(0)]],
                                  constant Transform &t [[buffer(1)]]) {
        uint base = vid * 6u;
        float2 p = float2(verts[base + 0u], verts[base + 1u]);
        float4 c = float4(verts[base + 2u], verts[base + 3u], verts[base + 4u], verts[base + 5u]);
        VertexOut out;
        out.position = float4(t.ax * p.x + t.bx, t.cy * p.y + t.dy, 0.0, 1.0);
        // Premultiply so blending matches a straight-alpha source-over.
        out.color = float4(c.rgb * c.a, c.a);
        return out;
    }

    fragment float4 scene_fragment(VertexOut in [[stage_in]]) {
        return in.color;
    }
    """
#endif
