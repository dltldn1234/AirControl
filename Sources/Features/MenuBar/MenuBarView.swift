import AppKit
import SwiftUI

struct MenuBarView: View {
    @StateObject private var viewModel = MenuBarViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AirControl", systemImage: "hand.raised")
                .font(.headline)

            Text(viewModel.statusMessage)
                .foregroundStyle(.secondary)

            Divider()

            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }

            Button("Quit AirControl") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 260)
    }
}
