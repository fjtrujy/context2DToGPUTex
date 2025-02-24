import Foundation
import Metal
import AppKit

class MetalView: NSView {
    struct Config {
        let device: MTLDevice
        let pixelFormat: MTLPixelFormat
        let frame: CGRect
    }
    private let config: Config
    private(set) var metalLayer: CAMetalLayer!
    
    init(config: Config) {
        self.config = config
        super.init(frame: config.frame)
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .duringViewResize
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var isFlipped: Bool {
        true
    }

    public override func makeBackingLayer() -> CALayer {
        let metalLayer = CAMetalLayer()
        metalLayer.device = config.device
        metalLayer.pixelFormat = config.pixelFormat
        self.metalLayer = metalLayer
        return metalLayer
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let window {
            self.metalLayer.contentsScale = window.backingScaleFactor
        }
    }
}
