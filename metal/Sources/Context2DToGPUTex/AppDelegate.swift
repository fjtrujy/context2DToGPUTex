import Foundation
import AppKit

private enum Constants {
    static let windowSize = CGSize(width: 800, height: 600)
    static let windowsFrame = CGRect(origin: .zero, size: windowSize)
}

final class AppDelegate: NSObject {
    private var renderer: Renderer?
    @MainActor func run() {
        let sharedApp = NSApplication.shared
        sharedApp.delegate = self
        sharedApp.run()
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
        guard let screen = window.screen ?? NSScreen.main else { fatalError()}
        let renderer = Renderer(
            windowFrame: Constants.windowsFrame,
            refreshInterval: screen.maximumRefreshInterval
        )
        
        window.contentView = renderer.metalView
        window.makeKeyAndOrderFront(nil)
        window.delegate = self
        window.title = "Context2DtoGPUTex"
        
        sharedApp.setActivationPolicy(.regular)
        sharedApp.activate(ignoringOtherApps: true)
        
        self.renderer = renderer
        renderer.startRenderingLoop()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(0)
    }
}
