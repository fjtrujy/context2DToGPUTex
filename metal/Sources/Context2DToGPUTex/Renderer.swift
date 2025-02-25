import Foundation
import AppKit
import Metal

class Renderer {
    private lazy var cpuContext = CGContext(
        data: nil,
        width: Int(windowFrame.width),
        height: Int(windowFrame.height),
        bitsPerComponent: 8,
        bytesPerRow: Int(windowFrame.width) * MemoryLayout<UInt32>.stride,
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
    
    private let windowFrame: CGRect
    private let refreshInterval: TimeInterval
    
    private lazy var gpuTexture: MTLTexture = {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(windowFrame.width),
            height: Int(windowFrame.height),
            mipmapped: false
        )
        
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead]

        return device.makeTexture(descriptor: descriptor)!
    }()
    private lazy var contentLength: Int = Int(windowFrame.width * windowFrame.height) * MemoryLayout<UInt32>.stride
    
    private lazy var gpuTextureBuffer: MTLBuffer = device.makeBuffer(length: contentLength)!
    
    private lazy var texturedShader: MTLRenderPipelineState = {
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        return try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }()
    
    private lazy var vertices: [Float] = [
        // Positions        // Texture Coordinates
        -1.0,  1.0, 0.0,    0.0, 0.0, // Top-left
        -1.0, -1.0, 0.0,    0.0, 1.0, // Bottom-left
         1.0,  1.0, 0.0,    1.0, 0.0, // Top-right
         1.0, -1.0, 0.0,    1.0, 1.0  // Bottom-right
    ]
    
    init(
        windowFrame: CGRect,
        refreshInterval: TimeInterval
    ) {
        self.windowFrame = windowFrame
        self.refreshInterval = refreshInterval
    }
    
    func startRenderingLoop() {
        Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.fillCPUContextRandomColor()
            self.drawFrame()
            print(Date().timeIntervalSince1970)
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
        
        cpuContext.setFillColor(bgColor)
        let rect = CGPath(
            rect: windowFrame,
            transform: nil
        )

        cpuContext.beginPath()
        cpuContext.addPath(rect)
        cpuContext.drawPath(using: .fill)
        
        cpuContext.setFillColor(textColor)
        let attrString = NSAttributedString(string: "Hello, World!")
        attrString.draw(in: windowFrame)
    }
    
    func drawFrame() {
        let drawable = metalView.nextDrawable
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = MTLRenderPassDescriptor()

        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        // Copy from CGContext to GPUTexture
        let encoder = commandBuffer.makeBlitCommandEncoder()!
        gpuTextureBuffer.contents().copyMemory(from: cpuContext.data!, byteCount: contentLength)
        let sourceSize = MTLSize(
            width: Int(windowFrame.width),
            height: Int(windowFrame.height),
            depth: 1
        )
        let destinationOrigin = MTLOrigin(x: 0, y: 0, z: 0)
        encoder.copy(
            from: gpuTextureBuffer,
            sourceOffset: 0,
            sourceBytesPerRow: Int(windowFrame.width) * MemoryLayout<UInt32>.stride,
            sourceBytesPerImage: 0,
            sourceSize: sourceSize,
            to: gpuTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: destinationOrigin
        )
        encoder.endEncoding()
        commandBuffer.addCompletedHandler { _ in
            print("Finished GPU rendering")
        }

        renderEncoder.setRenderPipelineState(texturedShader)
        renderEncoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Float>.size, index: 0)
        renderEncoder.setFragmentTexture(gpuTexture, index: 0)

        // Draw using a triangle strip
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
