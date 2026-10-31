import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
    @AppStorage("windowControlEnabled") private var windowControlEnabled = false
    @AppStorage("windowMoveSensitivity") private var windowMoveSensitivity = 1.0
    @AppStorage("windowResizeSmoothing") private var windowResizeSmoothing = 0.25
    @AppStorage("appSwitchEnabled") private var appSwitchEnabled = false
    @AppStorage("twoHandResizeEnabled") private var twoHandResizeEnabled = false
    @AppStorage("windowGestureMode") private var windowGestureMode = WindowGestureMode.idle.rawValue
    @AppStorage("windowControlTarget") private var windowControlTarget = "No window selected"
    @AppStorage("windowControlStatus") private var windowControlStatus = ""
    @AppStorage("airKeyboardScale") private var airKeyboardScale = 1.0
    @AppStorage("airKeyboardOpacity") private var airKeyboardOpacity = 0.94
    @AppStorage("airKeyboardSensitivity") private var airKeyboardSensitivity = 1.0
    @AppStorage("airKeyboardLanguage") private var airKeyboardLanguage = AirKeyboardLanguage.english.rawValue
    @AppStorage("airKeyboardFeedback") private var airKeyboardFeedback = true
    @State private var accessibilityAuthorized = CursorControlCoordinator.shared.isAccessibilityTrusted
    @State private var statusMessage = ""
    @StateObject private var airKeyboardCoordinator = AirKeyboardCoordinator.shared
    @StateObject private var calibrationManager = CalibrationManager.shared

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
                Toggle("Thumb + middle pinch enabled", isOn: $rightClickGestureEnabled)
                Toggle("Show camera preview", isOn: $showsCameraPreview)
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }

            PinchMappingSettingsSection()

            Section("Calibration") {
                Toggle(
                    "Mirror camera coordinates",
                    isOn: Binding(
                        get: { calibrationManager.profile.mirrorsCamera },
                        set: { calibrationManager.setMirrorsCamera($0) }
                    )
                )
                LabeledContent(
                    "Profile",
                    value: calibrationManager.profile.isCalibrated ? "Calibrated" : "Default range"
                )
                if let step = calibrationManager.currentStep {
                    Text(step.instruction)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Capture Step") {
                        calibrationManager.captureCurrentStep()
                    }
                    Button("Cancel Calibration") {
                        calibrationManager.reset()
                    }
                } else {
                    HStack {
                        Button("Start Calibration") {
                            calibrationManager.startWizard()
                        }
                        Button("Reset Calibration", role: .destructive) {
                            calibrationManager.reset()
                        }
                        .disabled(!calibrationManager.profile.isCalibrated)
                    }
                }
                Text(calibrationManager.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Start the camera before capturing samples. Calibration stays on this Mac user account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Window and app control") {
                LabeledContent("Current mode", value: windowGestureMode)
                LabeledContent("Control target", value: windowControlTarget)
                if !windowControlStatus.isEmpty {
                    Text(windowControlStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Window control mode", isOn: $windowControlEnabled)
                Slider(value: $windowMoveSensitivity, in: 0.4...2, step: 0.1) {
                    Text("Window move sensitivity")
                } minimumValueLabel: {
                    Text("Low")
                } maximumValueLabel: {
                    Text("High")
                }
                Slider(value: $windowResizeSmoothing, in: 0.05...0.8, step: 0.05) {
                    Text("Resize smoothing")
                } minimumValueLabel: {
                    Text("Responsive")
                } maximumValueLabel: {
                    Text("Steady")
                }
                Toggle("Two-hand window resizing", isOn: $twoHandResizeEnabled)
                    .disabled(!windowControlEnabled)
                Toggle("Three-finger app switching", isOn: $appSwitchEnabled)
                Text(
                    "Hold an open palm to enter window mode. Hold a fist to exit. "
                        + "Window and app control require Accessibility access."
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingsBackupSection()

            Section("Air Keyboard") {
                Toggle(
                    "Enable Air Keyboard mode",
                    isOn: Binding(
                        get: { airKeyboardCoordinator.isActive },
                        set: { enabled in
                            if enabled {
                                airKeyboardCoordinator.activate()
                            } else {
                                airKeyboardCoordinator.deactivate()
                            }
                        }
                    )
                )
                .disabled(!airKeyboardCoordinator.canActivate && !airKeyboardCoordinator.isActive)

                Picker("Layout", selection: $airKeyboardLanguage) {
                    ForEach(AirKeyboardLanguage.allCases) { language in
                        Text(language.rawValue).tag(language.rawValue)
                    }
                }
                .onChange(of: airKeyboardLanguage) { _, _ in applyAirKeyboardSettings() }

                Slider(value: $airKeyboardScale, in: 0.75...1.35, step: 0.05) {
                    Text("Keyboard size")
                }
                .onChange(of: airKeyboardScale) { _, _ in applyAirKeyboardSettings() }

                Slider(value: $airKeyboardOpacity, in: 0.5...1, step: 0.05) {
                    Text("Keyboard opacity")
                }
                .onChange(of: airKeyboardOpacity) { _, _ in applyAirKeyboardSettings() }

                Slider(value: $airKeyboardSensitivity, in: 0.6...1.6, step: 0.05) {
                    Text("Key selection sensitivity")
                }
                .onChange(of: airKeyboardSensitivity) { _, _ in applyAirKeyboardSettings() }

                Toggle("Show key input feedback", isOn: $airKeyboardFeedback)

                HStack {
                    Text(airKeyboardCoordinator.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset Keyboard Position") {
                        airKeyboardCoordinator.resetKeyboardPosition()
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 420)
        .onAppear {
            accessibilityAuthorized = CursorControlCoordinator.shared.isAccessibilityTrusted
            applyAirKeyboardSettings()
        }
    }

    private func applyAirKeyboardSettings() {
        let language = AirKeyboardLanguage(rawValue: airKeyboardLanguage) ?? .english
        airKeyboardCoordinator.updateSettings(
            scale: airKeyboardScale,
            opacity: airKeyboardOpacity,
            sensitivity: airKeyboardSensitivity,
            language: language
        )
    }
}

private struct SettingsBackupSection: View {
    @State private var statusMessage = ""

    var body: some View {
        Section("Settings backup") {
            HStack {
                Button("Export Settings…", action: exportSettings)
                Button("Import Settings…", action: importSettings)
            }
            Text("Only AirControl preferences are included. Imported cursor and keyboard control remain off.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "AirControl-settings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try AirControlSettingsBackup().write(to: url)
            statusMessage = "Settings exported."
        } catch {
            statusMessage = "Could not export settings: \(error.localizedDescription)"
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let backup = try AirControlSettingsBackup.read(from: url)
            CursorControlCoordinator.shared.emergencyStop()
            AirKeyboardCoordinator.shared.stop()
            try backup.apply()
            statusMessage = "Settings imported. Cursor and keyboard control remain off."
        } catch {
            statusMessage = "Could not import settings: \(error.localizedDescription)"
        }
    }
}

private struct PinchMappingSettingsSection: View {
    @AppStorage("indexPinchActionMapping")
    private var indexPinchActionMapping = PinchActionMapping.leftClick.rawValue
    @AppStorage("middlePinchActionMapping")
    private var middlePinchActionMapping = PinchActionMapping.rightClick.rawValue

    var body: some View {
        Section("Pinch mapping") {
            Picker("Thumb + index pinch", selection: $indexPinchActionMapping) {
                ForEach(PinchActionMapping.allCases) { mapping in
                    Text(mapping.title).tag(mapping.rawValue)
                }
            }
            Picker("Thumb + middle pinch", selection: $middlePinchActionMapping) {
                ForEach(PinchActionMapping.allCases) { mapping in
                    Text(mapping.title).tag(mapping.rawValue)
                }
            }
            if PinchMappingConflict.hasDuplicateAction(
                index: PinchActionMapping(rawValue: indexPinchActionMapping) ?? .leftClick,
                middle: PinchActionMapping(rawValue: middlePinchActionMapping) ?? .rightClick
            ) {
                Label("Both pinch gestures use the same action.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Button("Reset pinch mappings") {
                indexPinchActionMapping = PinchActionMapping.leftClick.rawValue
                middlePinchActionMapping = PinchActionMapping.rightClick.rawValue
            }
        }
    }
}
