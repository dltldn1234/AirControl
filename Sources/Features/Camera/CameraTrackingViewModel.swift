import Combine
import Foundation

@MainActor
final class CameraTrackingViewModel: ObservableObject {
    @Published private(set) var status = "Camera stopped"
    @Published private(set) var isStarting = false
    @Published private(set) var isRunning = false
    @Published private(set) var joints: [HandJoint] = []
    @Published private(set) var framesPerSecond = 0.0
    @Published private(set) var cursorControlEnabled = false
    @Published private(set) var accessibilityAuthorized = CursorControlCoordinator.shared.isAccessibilityTrusted

    let cameraManager = CameraManager()
    private let cursorCoordinator = CursorControlCoordinator.shared

    init() {
        UserDefaults.standard.set(false, forKey: "cursorControlEnabled")
        cameraManager.onFrame = { [weak self] joints, fps in
            self?.cursorCoordinator.processFrame(joints)
            Task { @MainActor in
                self?.joints = joints
                self?.framesPerSecond = fps
                self?.status = joints.isEmpty ? "No hand detected" : "Hand detected"
            }
        }
    }

    func startCamera() {
        guard !isStarting, !isRunning else { return }
        isStarting = true
        status = "Requesting camera access…"
        Task {
            do {
                try await cameraManager.start()
                isRunning = true
                cursorCoordinator.setCameraRunning(true)
                status = "Looking for a hand…"
            } catch {
                status = error.localizedDescription
            }
            isStarting = false
        }
    }

    func stopCamera() {
        guard isRunning || isStarting else { return }
        cursorCoordinator.setCameraRunning(false)
        cursorControlEnabled = false
        isStarting = false
        isRunning = false
        status = "Stopping camera…"
        Task {
            await cameraManager.stop()
            joints = []
            framesPerSecond = 0
            status = "Camera stopped"
        }
    }

    func setCursorControlEnabled(_ enabled: Bool) {
        guard !enabled || isRunning else {
            status = "Start the camera before enabling cursor control."
            return
        }
        if cursorCoordinator.setEnabled(enabled) {
            cursorControlEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: "cursorControlEnabled")
            accessibilityAuthorized = cursorCoordinator.isAccessibilityTrusted
            status = enabled ? "Cursor control active · Esc to stop" : "Cursor control stopped"
        } else {
            cursorControlEnabled = false
            accessibilityAuthorized = cursorCoordinator.isAccessibilityTrusted
            status = accessibilityAuthorized
                ? "Start the camera before enabling cursor control."
                : "Allow AirControl in System Settings → Privacy & Security → Accessibility."
        }
    }

    func requestAccessibilityAccess() {
        _ = cursorCoordinator.requestAccessibilityAccess()
        accessibilityAuthorized = cursorCoordinator.isAccessibilityTrusted
        status = accessibilityAuthorized
            ? "Accessibility access is ready."
            : "Grant AirControl access in Privacy & Security → Accessibility, then enable cursor control."
    }

    func emergencyStop() {
        setCursorControlEnabled(false)
    }
}
