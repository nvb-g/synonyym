import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AXIsProcessTrusted() {
            // Prompt once at launch to grant Accessibility
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }
}
