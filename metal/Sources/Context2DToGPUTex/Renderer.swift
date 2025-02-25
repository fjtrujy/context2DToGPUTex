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
        let commandBuffer = commandQueue.makeCommandBuffer()
        let renderPassDescriptor = MTLRenderPassDescriptor()

        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        if let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            // Add Metal drawing commands here
            renderEncoder.endEncoding()
        }

        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }

    
    
}
