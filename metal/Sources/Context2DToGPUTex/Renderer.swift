import Foundation
import AppKit
import Metal

private enum Constants {
    static let copySize: CGSize = .init(width: 4096, height: 4096)
}

class Renderer {
    private lazy var cpuContext = CGContext(
        data: nil,
        width: Int(copySize.width),
        height: Int(copySize.height),
        bitsPerComponent: 8,
        bytesPerRow: Int(copySize.width) * MemoryLayout<UInt32>.stride,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGImageByteOrderInfo.order32Little.rawValue
    )!
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
    
    private let windowFrame: CGRect
    private let copySize: CGSize
    private let refreshInterval: TimeInterval
    
    init(
        windowFrame: CGRect,
        copySize: CGSize,
        refreshInterval: TimeInterval
    ) {
        self.windowFrame = windowFrame
        self.copySize = copySize
        self.refreshInterval = refreshInterval
    }
    
    func startRenderingLoop() {
        print("refreshInterval \(refreshInterval)")
        Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.fillCPUContextRandomColor()
            self.drawFrame()
        }
    }
}

private extension Renderer {
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
        let attrString = NSAttributedString(string: "Hello, World!")
        attrString.draw(in: cgContextRect)
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
        gpuTextureBuffer.contents().copyMemory(from: cpuContext.data!, byteCount: contentLength)
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
