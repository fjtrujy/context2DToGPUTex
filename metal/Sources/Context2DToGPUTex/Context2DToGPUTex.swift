import Foundation
import AppKit

@main
enum Context2DToGPUTex {
    static func main() {
        let appDelegate = AppDelegate()
        // Adding this as workaround for avoiding duplicated windows when debugging DemoMacMetal
        // https://developer.apple.com/forums/thread/765445?answerId=810250022#810250022
        sleep(1)
        appDelegate.run()
    }
}
