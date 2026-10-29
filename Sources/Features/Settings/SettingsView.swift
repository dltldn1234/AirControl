import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("cursorControlEnabled") private var cursorControlEnabled = false
    @AppStorage("cursorSensitivity") private var cursorSensitivity = 1.0
    @AppStorage("cursorSmoothing") private var cursorSmoothing = 0.4
    @AppStorage("pinchSensitivity") private var pinchSensitivity = 1.0
    @AppStorage("dragStartDelay") private var dragStartDelay = 0.45
    @AppStorage("showsCameraPreview") private var showsCameraPreview = true
    @AppStorage("scrollSensitivity") private var scrollSensitivity = 1.0
    @AppStorage("reversesScrollDirection") private var reversesScrollDirection = false
    @AppStorage("rightClickEnabled") private var rightClickEnabled = true
    @AppStorage("gestureCursorEnabled") private var gestureCursorEnabled = true
    @AppStorage("leftClickEnabled") private var leftClickEnabled = true
    @AppStorage("dragEnabled") private var dragEnabled = true
    @AppStorage("scrollEnabled") private var scrollEnabled = true
    @AppStorage("rightClickGestureEnabled") private var rightClickGestureEnabled = true
    @State private var accessibilityAuthorized = CursorControlCoordinator.shared.isAccessibilityTrusted
    @State private var statusMessage = ""

    var body: some View {
        Form {
            Section("Permissions") {
                Label("Camera access is requested when you start the camera.", systemImage: "camera")
                HStack {
                    Label(
                        accessibilityAuthorized ? "Accessibility access granted" : "Accessibility access required",
                        systemImage: accessibilityAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                    )
                    Spacer()
                    Button("Request Access") {
                        _ = CursorControlCoordinator.shared.requestAccessibilityAccess()
                        accessibilityAuthorized = CursorControlCoordinator.shared.isAccessibilityTrusted
                        statusMessage = accessibilityAuthorized
                            ? "Accessibility access is ready."
                            : "Grant access in System Settings, then return here."
                    }
                    Button("Open Settings") {
                        guard let url = URL(
                            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                        ) else { return }
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Section("Cursor control") {
                Toggle("Enable cursor control", isOn: $cursorControlEnabled)
                    .onChange(of: cursorControlEnabled) { _, enabled in
                        let accepted = CursorControlCoordinator.shared.setEnabled(enabled)
                        if !accepted {
                            cursorControlEnabled = false
                            accessibilityAuthorized = CursorControlCoordinator.shared.isAccessibilityTrusted
                            statusMessage = accessibilityAuthorized
                                ? "Start the camera before enabling cursor control."
                                : "Grant Accessibility access before enabling cursor control."
                        } else {
                            statusMessage = enabled
                                ? "Cursor control active · press Esc to stop."
                                : "Cursor control stopped."
                        }
                    }
                Slider(value: $cursorSensitivity, in: 0.5...2, step: 0.1) {
                    Text("Cursor sensitivity")
                } minimumValueLabel: {
                    Text("Low")
                } maximumValueLabel: {
                    Text("High")
                }
                Slider(value: $cursorSmoothing, in: 0...0.9, step: 0.05) {
                    Text("Smoothing")
                } minimumValueLabel: {
                    Text("Responsive")
                } maximumValueLabel: {
                    Text("Steady")
                }
                Slider(value: $pinchSensitivity, in: 0.6...1.4, step: 0.05) {
                    Text("Pinch sensitivity")
                }
                Slider(value: $dragStartDelay, in: 0.2...1, step: 0.05) {
                    Text("Drag hold time")
                }
                Slider(value: $scrollSensitivity, in: 0.4...3, step: 0.1) {
                    Text("Scroll sensitivity")
                } minimumValueLabel: {
                    Text("Slow")
                } maximumValueLabel: {
                    Text("Fast")
                }
                Toggle("Reverse scroll direction", isOn: $reversesScrollDirection)
            }

            Section("Gestures") {
                Toggle("Cursor movement", isOn: $gestureCursorEnabled)
                Toggle("Left click", isOn: $leftClickEnabled)
                Toggle("Drag", isOn: $dragEnabled)
                Toggle("Two-finger scroll", isOn: $scrollEnabled)
                Toggle("Right click enabled", isOn: $rightClickEnabled)
                Toggle("Thumb + middle finger right click", isOn: $rightClickGestureEnabled)
                    .disabled(!rightClickEnabled)
                Toggle("Show camera preview", isOn: $showsCameraPreview)
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 420)
        .onAppear {
            accessibilityAuthorized = CursorControlCoordinator.shared.isAccessibilityTrusted
        }
    }
}
