import Foundation
import AppKit
import Metal

class Renderer {
    private lazy var cpuContext: CGContext = {
        CGContext(
            data: cgContextFromBuffer ? gpuTextureBuffer.contents() : nil,
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
        
        descriptor.storageMode = .managed
        descriptor.usage = [.shaderRead]

        return device.makeTexture(descriptor: descriptor)!
    }()
    private lazy var contentLength: Int = Int(copySize.width * copySize.height) * MemoryLayout<UInt32>.stride
    
    private lazy var gpuTextureBuffer: MTLBuffer = device.makeBuffer(length: contentLength)!
    
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
    private let cgContextFromBuffer: Bool
    private let windowFrame: CGRect
    private let copySize: CGSize
    private let refreshInterval: TimeInterval
    private let displayLink: CVDisplayLink
    
    private var lastFrameTime: UInt64 = .zero
    
    init(
        onFPSUpdate: @escaping (Double) -> Void,
        cgContextFromBuffer: Bool,
        windowFrame: CGRect,
        copySize: CGSize,
        refreshInterval: TimeInterval
    ) {
        self.onFPSUpdate = onFPSUpdate
        self.cgContextFromBuffer = cgContextFromBuffer
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
            
            let currentHostTime = inNow.pointee.hostTime
            let frameDuration = Double(currentHostTime - renderer.lastFrameTime) / Double(NSEC_PER_SEC)
            let fps = (1.0/frameDuration).rounded()
            
            renderer.lastFrameTime = currentHostTime
            renderer.onFPSUpdate(fps)
            
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
        
        let cgContextRect = CGRect(origin: .zero, size: copySize)
        cpuContext.setFillColor(bgColor)
        let rect = CGPath(
            rect: cgContextRect,
            transform: nil
        )

        cpuContext.beginPath()
        cpuContext.addPath(rect)
        cpuContext.drawPath(using: .fill)
        
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
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = MTLRenderPassDescriptor()

        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        
        // Copy from CGContext to GPUTexture
        let encoder = commandBuffer.makeBlitCommandEncoder()!
        if !cgContextFromBuffer {
            gpuTextureBuffer.contents().copyMemory(from: cpuContext.data!, byteCount: contentLength)
        }
        let sourceSize = MTLSize(
            width: Int(copySize.width),
            height: Int(copySize.height),
            depth: 1
        )
        let destinationOrigin = MTLOrigin(x: 0, y: 0, z: 0)
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
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(texturedShader)
        renderEncoder.setFragmentTexture(gpuTexture, index: 0)

        // Draw using a triangle strip
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
