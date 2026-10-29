import SwiftUI

@main
struct AirControlApp: App {
    @NSApplicationDelegateAdaptor(AirControlAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("AirControl", systemImage: "hand.raised") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
