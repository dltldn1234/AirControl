import AppKit

@MainActor
final class AirControlAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.set(false, forKey: "cursorControlEnabled")
        CursorControlCoordinator.shared.stop()
    }

    func applicationWillTerminate(_ notification: Notification) {
        CursorControlCoordinator.shared.stop()
    }
}
