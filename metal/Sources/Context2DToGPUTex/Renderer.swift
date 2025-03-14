import Foundation
import AppKit
import Metal

class Renderer {
    private lazy var cpuContext: CGContext = {
        CGContext(
            data: cgContextFromGPUBuffer ? gpuTextureBuffer.contents() : nil,
            width: Int(copySize.width),
            height: Int(copySize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(copySize.width) * MemoryLayout<UInt32>.stride,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGImageByteOrderInfo.order32Little.rawValue
        )!
    }()
    private lazy var device = MTLCreateSystemDefaultDevice()!
    private lazy var commandQueue: MTLCommandQueue = {
        self.device.makeCommandQueue()!
    }()
    private(set) lazy var metalView: MetalView = {
        let metalViewConfig = MetalView.Config(
            device: device,
            pixelFormat: .bgra8Unorm,
            frame: windowFrame
        )
        return MetalView(config: metalViewConfig)
    }()
    
    private lazy var gpuTexture: MTLTexture = {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(copySize.width),
            height: Int(copySize.height),
            mipmapped: false
        )
        
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .pixelFormatView]

        return device.makeTexture(descriptor: descriptor)!
    }()
    private lazy var contentLength: Int = Int(copySize.width * copySize.height) * MemoryLayout<UInt32>.stride
    
    private lazy var gpuTextureBuffer: MTLBuffer = device.makeBuffer(
        length: contentLength,
        options: .storageModeManaged
    )!
    
    private lazy var texturedShader: MTLRenderPipelineState = {
        let library = try! device.makeDefaultLibrary(bundle: .module)
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        return try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }()
    
    private let onFPSUpdate: (Double) -> Void
    private let cgContextFromGPUBuffer: Bool
    private let windowFrame: CGRect
    private let copySize: CGSize
    private let refreshInterval: TimeInterval
    private let displayLink: CVDisplayLink
    
    private var lastFrameTime: UInt64 = .zero
    
    init(
        onFPSUpdate: @escaping (Double) -> Void,
        cgContextFromGPUBuffer: Bool,
        windowFrame: CGRect,
        copySize: CGSize,
        refreshInterval: TimeInterval
    ) {
        self.onFPSUpdate = onFPSUpdate
        self.cgContextFromGPUBuffer = cgContextFromGPUBuffer
        self.windowFrame = windowFrame
        self.copySize = copySize
        self.refreshInterval = refreshInterval
        
        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink else { fatalError("Unable to create CVDisplayLink") }
        self.displayLink = displayLink
    }
    
    func startRenderingLoop() {
        let displayLinkOutputCallback: CVDisplayLinkOutputCallback = {(
            displayLink: CVDisplayLink,
            inNow: UnsafePointer<CVTimeStamp>,
            inOutputTime: UnsafePointer<CVTimeStamp>,
            flagsIn: CVOptionFlags,
            flagsOut: UnsafeMutablePointer<CVOptionFlags>,
            displayLinkContext: UnsafeMutableRawPointer?
        ) -> CVReturn in
            let renderer = unsafeBitCast(displayLinkContext, to: Renderer.self)
            
            renderer.fillCPUContextRandomColor()
            renderer.drawFrame()
            
            let currentTime = inNow.pointee.hostTime
            if renderer.lastFrameTime != 0 {
                let frameDuration = Double(currentTime - renderer.lastFrameTime) / Double(CVGetHostClockFrequency())
                let fps = (1.0/frameDuration).rounded()
                renderer.onFPSUpdate(fps)
            }
            
            renderer.lastFrameTime = currentTime
            
            return kCVReturnSuccess
        }
        
        let displayUserInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(displayLink, displayLinkOutputCallback, displayUserInfo)
        CVDisplayLinkStart(displayLink)
    }
}

fileprivate extension Renderer {
    func fillCPUContextRandomColor() {
        let red: CGFloat = CGFloat.random(in: 0...1)
        let green: CGFloat = CGFloat.random(in: 0...1)
        let blue: CGFloat = CGFloat.random(in: 0...1)
        let bgColor = CGColor(red: red, green: green, blue: blue, alpha: 1)
        let textColor = CGColor(red: 1.0 - red, green: 1.0 - green, blue: 1.0 - blue, alpha: 1)
        
        // Fill background
        let cgContextRect = CGRect(origin: .zero, size: copySize)
        cpuContext.setFillColor(bgColor)
        cpuContext.fill(cgContextRect)
        
        // Draw text more efficiently
        cpuContext.setFillColor(textColor)
        
        let attrString = NSAttributedString(
            string: "Hello, World!",
            attributes: [
                .font: NSFont.systemFont(ofSize: copySize.width/10),
                .foregroundColor: NSColor(cgColor: textColor)!
                ]
        )
        let textStorage = NSTextStorage(attributedString: attrString)
        let textContainer = NSTextContainer(size: CGSize(width: copySize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        
        
        let at = NSPoint(x: copySize.width / 4, y: copySize.height / 3)
        NSGraphicsContext.saveGraphicsState()
        let nsgc = NSGraphicsContext(cgContext: cpuContext, flipped: true)
        NSGraphicsContext.current = nsgc
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: at)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: at)
        NSGraphicsContext.restoreGraphicsState()
    }
    
    func drawFrame() {
        let drawable = metalView.nextDrawable
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // Copy from CGContext to GPUTexture
        if !cgContextFromGPUBuffer {
            let bufferContents = gpuTextureBuffer.contents()
            bufferContents.copyMemory(from: cpuContext.data!, byteCount: contentLength)
            gpuTextureBuffer.didModifyRange(0..<contentLength)
        }
        
        if let encoder = commandBuffer.makeBlitCommandEncoder() {
            let sourceSize = MTLSize(
                width: Int(copySize.width),
                height: Int(copySize.height),
                depth: 1
            )
            let destinationOrigin = MTLOrigin(x: 0, y: 0, z: 0)
            encoder.synchronize(resource: gpuTextureBuffer) // Ensure CPU writes are visible to GPU
            encoder.copy(
                from: gpuTextureBuffer,
                sourceOffset: 0,
                sourceBytesPerRow: Int(copySize.width) * MemoryLayout<UInt32>.stride,
                sourceBytesPerImage: 0,
                sourceSize: sourceSize,
                to: gpuTexture,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: destinationOrigin
            )
            encoder.endEncoding()
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 0, blue: 0, alpha: 1)

        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.setRenderPipelineState(texturedShader)
            renderEncoder.setFragmentTexture(gpuTexture, index: 0)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
