import Combine
import Foundation

@MainActor
final class CameraTrackingViewModel: ObservableObject {
    @Published private(set) var status = "Camera stopped"
    @Published private(set) var isStarting = false
    @Published private(set) var isRunning = false
    @Published private(set) var joints: [HandJoint] = []
    @Published private(set) var framesPerSecond = 0.0
    @Published private(set) var inferenceMilliseconds = 0.0
    @Published private(set) var cpuUsagePercent = 0.0
    @Published private(set) var cursorControlEnabled = false
    @Published private(set) var accessibilityAuthorized = CursorControlCoordinator.shared.isAccessibilityTrusted
    @Published private(set) var gestureStatus = ActiveGesture.trackingLost
    @Published private(set) var windowGestureMode = WindowGestureMode.idle
    @Published private(set) var windowTarget = "No window selected"
    @Published private(set) var windowControlStatus = ""

    let cameraManager = CameraManager()
    private let cursorCoordinator = CursorControlCoordinator.shared
    private var lastFrameUIUpdate = 0.0
    private var lastMetricsUIUpdate = 0.0

    init() {
        cursorCoordinator.setGestureStatusHandler { [weak self] state in
            self?.gestureStatus = state
        }
        cursorCoordinator.setWindowStatusHandler { [weak self] mode, target, message in
            self?.windowGestureMode = mode
            self?.windowTarget = target
            self?.windowControlStatus = message
        }
        cameraManager.onFrame = { [weak self] hands, fps in
            self?.cursorCoordinator.processFrame(hands)
            Task { @MainActor in
                let now = ProcessInfo.processInfo.systemUptime
                guard now - (self?.lastFrameUIUpdate ?? 0) >= 1.0 / 20 else { return }
                self?.lastFrameUIUpdate = now
                self?.joints = hands.flatMap { $0 }
                self?.framesPerSecond = fps
                self?.status = hands.isEmpty ? "No hand detected" : "Hand detected · \(hands.count)"
            }
        }
        cameraManager.onPerformance = { [weak self] inferenceMilliseconds, cpuUsagePercent in
            Task { @MainActor in
                let now = ProcessInfo.processInfo.systemUptime
                guard now - (self?.lastMetricsUIUpdate ?? 0) >= 0.2 else { return }
                self?.lastMetricsUIUpdate = now
                self?.inferenceMilliseconds = inferenceMilliseconds
                self?.cpuUsagePercent = cpuUsagePercent
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
        UserDefaults.standard.set(false, forKey: "cursorControlEnabled")
        isStarting = false
        isRunning = false
        status = "Stopping camera…"
        Task {
            await cameraManager.stop()
            joints = []
            windowGestureMode = .idle
            windowTarget = "No window selected"
            framesPerSecond = 0
            inferenceMilliseconds = 0
            cpuUsagePercent = 0
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
            gestureStatus = .trackingLost
            UserDefaults.standard.set(false, forKey: "cursorControlEnabled")
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
        cursorCoordinator.emergencyStop()
        cursorControlEnabled = false
        gestureStatus = .trackingLost
        windowGestureMode = .idle
        windowTarget = "No window selected"
        windowControlStatus = "Emergency stop · all gesture controls are off."
    }
}
