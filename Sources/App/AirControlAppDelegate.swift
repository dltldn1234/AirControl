import AppKit

@MainActor
final class AirControlAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        CursorControlCoordinator.shared.stop()
    }
}
