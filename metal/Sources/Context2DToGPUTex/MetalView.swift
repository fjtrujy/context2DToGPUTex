import Foundation
import Metal
import AppKit

class MetalView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        
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
        CAMetalLayer()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let window {
//            self.metalLayer.contentsScale = window.backingScaleFactor
        }
    }
}
