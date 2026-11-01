import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsBackupSection: View {
    @State private var statusMessage = ""

    var body: some View {
        Section("Settings backup") {
            HStack {
                Button("Export Settings…", action: exportSettings)
                Button("Import Settings…", action: importSettings)
            }
            Text(
                "Only AirControl preferences are included. Imported cursor and keyboard control remain off."
            )
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

struct PinchMappingSettingsSection: View {
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
                Label(
                    "Both pinch gestures use the same action.",
                    systemImage: "exclamationmark.triangle"
                )
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

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case camera
    case cursor
    case gestures
    case window
    case keyboard

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .camera: "Camera & calibration"
        case .cursor: "Cursor"
        case .gestures: "Gestures"
        case .window: "Window control"
        case .keyboard: "Air Keyboard"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Permissions and preference backup."
        case .camera: "Preview, camera mirroring, and tracking calibration."
        case .cursor: "Movement, smoothing, and scroll behavior."
        case .gestures: "Choose which hand gestures trigger actions."
        case .window: "Move windows and switch between apps."
        case .keyboard: "Configure the floating keyboard and text input."
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .camera: "camera"
        case .cursor: "cursorarrow"
        case .gestures: "hand.tap"
        case .window: "macwindow"
        case .keyboard: "keyboard"
        }
    }
}

enum AirSettingsMetrics {
    static let contentInset: CGFloat = 20
    static let sectionSpacing: CGFloat = 12
}

enum AirSettingsColors {
    static let canvas = Color(nsColor: .windowBackgroundColor)
}

struct CalibrationSettingsSection: View {
    @StateObject private var calibrationManager = CalibrationManager.shared

    var body: some View {
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
                value: calibrationManager.profile.isCalibrated
                    ? "Calibrated" : "Default range"
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
            Text(
                "Start the camera before capturing samples. Calibration stays on this Mac user account."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct WindowControlSettingsSection: View {
    @AppStorage("windowControlEnabled") private var windowControlEnabled = false
    @AppStorage("windowMoveSensitivity") private var windowMoveSensitivity = 1.0
    @AppStorage("windowResizeSmoothing") private var windowResizeSmoothing = 0.25
    @AppStorage("appSwitchEnabled") private var appSwitchEnabled = false
    @AppStorage("twoHandResizeEnabled") private var twoHandResizeEnabled = false
    @AppStorage("windowGestureMode") private var windowGestureMode = WindowGestureMode.idle.rawValue
    @AppStorage("windowControlTarget") private var windowControlTarget = "No window selected"
    @AppStorage("windowControlStatus") private var windowControlStatus = ""

    var body: some View {
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
    }
}

struct CameraDeviceSettingsSection: View {
    @AppStorage("showsCameraPreview") private var showsCameraPreview = true
    @AppStorage("selectedCameraUniqueID") private var selectedCameraUniqueID = ""
    @State private var cameras = CameraManager.availableCameras()
    @State private var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        Section("Camera") {
            Toggle("Show camera preview", isOn: $showsCameraPreview)
            HStack {
                Label(permissionPresentation.message, systemImage: permissionPresentation.symbol)
                    .foregroundStyle(authorizationStatus == .denied ? .orange : .secondary)
                Spacer()
                Button("Refresh") {
                    refreshCameras()
                }
                .accessibilityHint("Refreshes the list of available video cameras.")
            }
            if cameras.isEmpty {
                Label("No cameras found", systemImage: "video.slash")
                    .foregroundStyle(.secondary)
                Text("Connect a camera, then refresh this list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Camera device", selection: $selectedCameraUniqueID) {
                    Text("Automatic · built-in first").tag("")
                    ForEach(cameras) { camera in
                        Text(camera.isBuiltIn ? "\(camera.name) · Built-in" : camera.name)
                            .tag(camera.id)
                    }
                }
                if !selectedCameraUniqueID.isEmpty,
                   !cameras.contains(where: { $0.id == selectedCameraUniqueID }) {
                    Label("Saved camera is disconnected; the next start will use a fallback camera.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Text("Camera selection takes effect the next time you start the camera.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if permissionPresentation.needsSystemSettings {
                Button("Open Camera Privacy Settings") {
                    guard let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
                    ) else { return }
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .onAppear(perform: refreshCameras)
        .onReceive(NotificationCenter.default.publisher(for: .AVCaptureDeviceWasConnected)) { _ in
            refreshCameras()
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVCaptureDeviceWasDisconnected)) { _ in
            refreshCameras()
        }
    }

    private var permissionPresentation: CameraPermissionPresentation {
        .forStatus(authorizationStatus)
    }

    private func refreshCameras() {
        cameras = CameraManager.availableCameras()
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
}
