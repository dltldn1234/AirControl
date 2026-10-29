import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Permissions") {
                Label("Camera access will be used for hand tracking in a later phase.", systemImage: "camera")
                Label("Accessibility access will be needed for future cursor control.", systemImage: "accessibility")
            }

            Section("Status") {
                Text("AirControl is a project scaffold. Camera tracking and system input are not implemented.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 440, minHeight: 220)
    }
}
