import Foundation
import AppKit

class AppDelegate: NSObject {
    
    @MainActor func run() {
        let sharedApp = NSApplication.shared
        sharedApp.delegate = self
        sharedApp.run()
    }
}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let windowSize = CGSize(width: 800, height: 600)
        let windowsFrame = CGRect(origin: .zero, size: windowSize)
        let window = NSWindow(
            contentRect: windowsFrame,
            styleMask: [.closable, .miniaturizable, .titled],
            backing: .buffered,
            defer: false
        )
        
        let sharedApp = NSApplication.shared
        
        window.contentView = MetalView(frame: windowsFrame)
        window.makeKeyAndOrderFront(nil)
        window.delegate = self
        window.title = "Context2DtoGPUTex"
        
        sharedApp.setActivationPolicy(.regular)
        sharedApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(0)
    }
}
