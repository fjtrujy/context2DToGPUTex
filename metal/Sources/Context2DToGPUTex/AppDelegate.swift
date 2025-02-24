import Foundation
import AppKit

private enum Constants {
    static let windowSize = CGSize(width: 800, height: 600)
    static let windowsFrame = CGRect(origin: .zero, size: windowSize)
}

final class AppDelegate: NSObject {
    let cpuContext: CGContext = {
        guard let context = CGContext(
            data: nil,
            width: Int(Constants.windowSize.width),
            height: Int(Constants.windowSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(Constants.windowSize.width) * MemoryLayout<UInt32>.stride,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGImageByteOrderInfo.order32Little.rawValue
        ) else { fatalError("Couldn't create CGContext")}
        return context
    }()
    
    @MainActor func run() {
        let sharedApp = NSApplication.shared
        sharedApp.delegate = self
        sharedApp.run()
    }
}

private extension AppDelegate {
    func fillCPUContextRandomColor() {
        let red: CGFloat = CGFloat.random(in: 0...1)
        let green: CGFloat = CGFloat.random(in: 0...1)
        let blue: CGFloat = CGFloat.random(in: 0...1)
        let bgColor = CGColor(red: red, green: green, blue: blue, alpha: 1)
        let textColor = CGColor(red: 1.0 - red, green: 1.0 - green, blue: 1.0 - blue, alpha: 1)
        
        cpuContext.setFillColor(bgColor)
        let rect = CGPath(
            rect: Constants.windowsFrame,
            transform: nil
        )

        cpuContext.beginPath()
        cpuContext.addPath(rect)
        cpuContext.drawPath(using: .fill)
        
        cpuContext.setFillColor(textColor)
        let attrString = NSAttributedString(string: "Hello, World!")
        attrString.draw(in: Constants.windowsFrame)
    }
    
    func startRenderingLoop(interval: TimeInterval) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.fillCPUContextRandomColor()
            print(Date().timeIntervalSince1970)
        }
    }
}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let window = NSWindow(
            contentRect: Constants.windowsFrame,
            styleMask: [.closable, .miniaturizable, .titled],
            backing: .buffered,
            defer: false
        )
        
        let sharedApp = NSApplication.shared
        
        let device = MTLCreateSystemDefaultDevice()!
        let metalViewConfig = MetalView.Config(
            device: device,
            pixelFormat: .bgra8Unorm,
            frame: Constants.windowsFrame
        )
        window.contentView = MetalView(config: metalViewConfig)
        window.makeKeyAndOrderFront(nil)
        window.delegate = self
        window.title = "Context2DtoGPUTex"
        
        sharedApp.setActivationPolicy(.regular)
        sharedApp.activate(ignoringOtherApps: true)
        
        guard let screen = window.screen ?? NSScreen.main else { fatalError()}
        startRenderingLoop(interval: screen.maximumRefreshInterval)
        
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(0)
    }
}
