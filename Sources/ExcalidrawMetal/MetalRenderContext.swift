#if canImport(Metal)
    import CoreGraphics
    import Foundation
    import Metal
    import QuartzCore

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
        /// Pipeline + format for presenting to a `CAMetalLayer` drawable, which
        /// only supports `bgra8Unorm` (not the off-screen `rgba8Unorm`).
        private let drawablePipeline: MTLRenderPipelineState
        private let sampleCount = 4
        private let pixelFormat: MTLPixelFormat = .rgba8Unorm
        private let drawablePixelFormat: MTLPixelFormat = .bgra8Unorm

        // Persistent GPU resources reused across frames: the MSAA + resolve
        // render targets (rebuilt only when the pixel size changes) and a
        // growable vertex buffer (reallocated only when geometry outgrows it).
        // Reusing these avoids a per-frame allocation of ~15 MB of textures and
        // a fresh vertex buffer every frame.
        private var msaaTexture: MTLTexture?
        private var resolveTexture: MTLTexture?
        private var textureSize: (width: Int, height: Int)?
        private var vertexBuffer: MTLBuffer?
        private var readbackBuffer: [UInt8] = []
        // Separate MSAA target for the present-to-drawable path (its resolve is
        // the drawable's own texture, not our cached resolve).
        private var drawableMSAATexture: MTLTexture?
        private var drawableMSAASize: (width: Int, height: Int)?

        init?() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let queue = device.makeCommandQueue() else { return nil }
            guard let pipeline = Self.makePipeline(device: device, sampleCount: 4, pixelFormat: .rgba8Unorm),
                  let drawablePipeline = Self.makePipeline(device: device, sampleCount: 4, pixelFormat: .bgra8Unorm)
            else {
                return nil
            }
            self.device = device
            self.queue = queue
            self.pipeline = pipeline
            self.drawablePipeline = drawablePipeline
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

        /// Rasterize `vertices` (3 floats/vertex: x, y, packed-RGBA8) into a
        /// `pixelWidth × pixelHeight` RGBA image over `clearColor`. Returns `nil`
        /// on any GPU failure, or when there's nothing to draw (no triangles and
        /// a transparent clear). This is the read-back path: it copies the GPU
        /// result back to the CPU as a `CGImage` (used by the `SceneRendering`
        /// protocol path that composites into a `CGContext`).
        func image(
            vertices: [Float], transform: Transform, clearColor: MTLClearColor,
            pixelWidth: Int, pixelHeight: Int
        ) -> CGImage? {
            guard hasContent(vertices, clearColor), pixelWidth > 0, pixelHeight > 0,
                  let (msaaTexture, resolveTexture) = targets(width: pixelWidth, height: pixelHeight) else {
                return nil
            }
            runPass(
                pipeline: pipeline, vertices: vertices, transform: transform, clearColor: clearColor,
                msaa: msaaTexture, resolve: resolveTexture, present: nil, wait: true
            )
            return makeImage(from: resolveTexture, width: pixelWidth, height: pixelHeight)
        }

        /// Direct path: render into an off-screen target and let the GPU finish,
        /// but skip the read-back/`CGImage` round-trip entirely. Returns whether
        /// the GPU pass ran. This is what a present-to-drawable frame costs, minus
        /// the (async) present — used to measure the read-back savings headlessly.
        func renderNoReadback(
            vertices: [Float], transform: Transform, clearColor: MTLClearColor,
            pixelWidth: Int, pixelHeight: Int
        ) -> Bool {
            guard hasContent(vertices, clearColor), pixelWidth > 0, pixelHeight > 0,
                  let (msaaTexture, resolveTexture) = targets(width: pixelWidth, height: pixelHeight) else {
                return false
            }
            runPass(
                pipeline: pipeline, vertices: vertices, transform: transform, clearColor: clearColor,
                msaa: msaaTexture, resolve: resolveTexture, present: nil, wait: true
            )
            return true
        }

        /// On-screen path: render into `drawable.texture` and present it. No
        /// read-back, no `CGContext` — the GPU output goes straight to the
        /// display. `present`/`commit` are async (no `waitUntilCompleted`), so
        /// frames pipeline.
        func renderToDrawable(
            _ drawable: CAMetalDrawable, vertices: [Float], transform: Transform, clearColor: MTLClearColor
        ) {
            let resolve = drawable.texture
            guard let msaa = drawableMSAA(width: resolve.width, height: resolve.height) else { return }
            runPass(
                pipeline: drawablePipeline, vertices: vertices, transform: transform, clearColor: clearColor,
                msaa: msaa, resolve: resolve, present: drawable, wait: false
            )
        }

        private func hasContent(_ vertices: [Float], _ clearColor: MTLClearColor) -> Bool {
            vertices.count / 3 >= 3 || clearColor.alpha > 0
        }

        /// Encode one MSAA render pass (clear + triangles), resolving into
        /// `resolve`. Optionally presents `present` and/or blocks until the GPU
        /// finishes.
        private func runPass(
            pipeline: MTLRenderPipelineState, vertices: [Float], transform: Transform,
            clearColor: MTLClearColor, msaa: MTLTexture, resolve: MTLTexture,
            present: CAMetalDrawable?, wait: Bool
        ) {
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = msaa
            pass.colorAttachments[0].resolveTexture = resolve
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .multisampleResolve
            pass.colorAttachments[0].clearColor = clearColor

            guard let commandBuffer = queue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }

            let vertexCount = vertices.count / 3
            if vertexCount >= 3, let vertexBuffer = uploadVertices(vertices) {
                var transform = transform
                encoder.setRenderPipelineState(pipeline)
                encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                encoder.setVertexBytes(&transform, length: MemoryLayout<Transform>.stride, index: 1)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
            }
            encoder.endEncoding()
            if let present { commandBuffer.present(present) }
            commandBuffer.commit()
            if wait { commandBuffer.waitUntilCompleted() }
        }

        /// MSAA render target matching a drawable's size, cached and rebuilt only
        /// when the drawable size changes.
        private func drawableMSAA(width: Int, height: Int) -> MTLTexture? {
            if let drawableMSAATexture, drawableMSAASize?.width == width, drawableMSAASize?.height == height {
                return drawableMSAATexture
            }
            guard let msaa = makeTexture(
                width: width, height: height, multisampled: true, format: drawablePixelFormat
            ) else { return nil }
            drawableMSAATexture = msaa
            drawableMSAASize = (width, height)
            return msaa
        }

        /// The MSAA + resolve render targets for `width × height`, rebuilt only
        /// when the size changes.
        private func targets(width: Int, height: Int) -> (msaa: MTLTexture, resolve: MTLTexture)? {
            if let msaaTexture, let resolveTexture, textureSize?.width == width, textureSize?.height == height {
                return (msaaTexture, resolveTexture)
            }
            guard let msaa = makeTexture(width: width, height: height, multisampled: true),
                  let resolve = makeTexture(width: width, height: height, multisampled: false) else { return nil }
            msaaTexture = msaa
            resolveTexture = resolve
            textureSize = (width, height)
            return (msaa, resolve)
        }

        /// Copy `vertices` into the reusable vertex buffer, growing it (with
        /// headroom) only when the geometry no longer fits.
        private func uploadVertices(_ vertices: [Float]) -> MTLBuffer? {
            let byteLength = vertices.count * MemoryLayout<Float>.stride
            if vertexBuffer == nil || (vertexBuffer?.length ?? 0) < byteLength {
                guard let buffer = device.makeBuffer(length: byteLength * 2, options: .storageModeShared) else {
                    return nil
                }
                vertexBuffer = buffer
            }
            guard let vertexBuffer else { return nil }
            vertices.withUnsafeBytes { src in
                _ = memcpy(vertexBuffer.contents(), src.baseAddress!, byteLength)
            }
            return vertexBuffer
        }

        private func makeTexture(
            width: Int, height: Int, multisampled: Bool, format: MTLPixelFormat? = nil
        ) -> MTLTexture? {
            let descriptor = MTLTextureDescriptor()
            descriptor.pixelFormat = format ?? pixelFormat
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

        /// Read the resolved RGBA texture back into a `CGImage` (row 0 = top),
        /// reusing the readback byte buffer across frames.
        private func makeImage(from texture: MTLTexture, width: Int, height: Int) -> CGImage? {
            let bytesPerRow = width * 4
            let byteCount = bytesPerRow * height
            if readbackBuffer.count != byteCount {
                readbackBuffer = [UInt8](repeating: 0, count: byteCount)
            }
            let region = MTLRegionMake2D(0, 0, width, height)
            readbackBuffer.withUnsafeMutableBytes { raw in
                texture.getBytes(raw.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
            }
            guard let provider = CGDataProvider(data: Data(readbackBuffer) as CFData) else { return nil }
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
        // 3 floats per vertex: x, y, and an RGBA8 color packed into a uint that
        // was bit-cast to float on the CPU. Halves vertex bandwidth vs 4 color
        // floats.
        uint base = vid * 3u;
        float2 p = float2(verts[base + 0u], verts[base + 1u]);
        float4 c = unpack_unorm4x8_to_float(as_type<uint>(verts[base + 2u]));
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
