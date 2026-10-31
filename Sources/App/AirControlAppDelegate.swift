import AppKit

@MainActor
final class AirControlAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.set(false, forKey: "cursorControlEnabled")
        UserDefaults.standard.set(false, forKey: "airKeyboardEnabled")
        CursorControlCoordinator.shared.stop()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AirKeyboardCoordinator.shared.stop()
        CursorControlCoordinator.shared.stop()
    }
}
