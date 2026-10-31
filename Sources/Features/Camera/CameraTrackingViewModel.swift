import Combine
import Foundation

@MainActor
final class CameraTrackingViewModel: ObservableObject {
    @Published private(set) var status = "Camera stopped"
    @Published private(set) var isStarting = false
    @Published private(set) var isStopping = false
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
    private let airKeyboardCoordinator = AirKeyboardCoordinator.shared
    private let calibrationManager = CalibrationManager.shared
    private var lastFrameUIUpdate = 0.0
    private var lastMetricsUIUpdate = 0.0
    private var cameraLifecycle = CameraLifecycleGeneration()
    private var cameraStartTask: Task<Void, Never>?

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
                self?.airKeyboardCoordinator.processFrame(hands)
                self?.calibrationManager.observe(hands)
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
        cameraManager.onStatus = { [weak self] cameraStatus in
            Task { @MainActor in self?.handleCameraStatus(cameraStatus) }
        }
    }

    private func handleCameraStatus(_ cameraStatus: CameraManagerStatus) {
        switch cameraStatus {
        case let .interrupted(message):
            status = message
        case .resumed:
            status = isRunning ? "Camera resumed · looking for a hand…" : "Camera resumed."
        case let .failed(message):
            cursorCoordinator.setCameraRunning(false)
            AirKeyboardCoordinator.shared.setCameraRunning(false)
            _ = cameraLifecycle.invalidate()
            cameraStartTask?.cancel()
            cameraStartTask = nil
            isRunning = false
            isStarting = false
            isStopping = false
            cursorControlEnabled = false
            UserDefaults.standard.set(false, forKey: "cursorControlEnabled")
            status = "Camera error: \(message)"
        }
    }

    func startCamera() {
        guard !isStarting, !isRunning, !isStopping else { return }
        let generation = cameraLifecycle.begin()
        isStarting = true
        status = "Requesting camera access…"
        cameraStartTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if cameraLifecycle.isCurrent(generation) {
                    cameraStartTask = nil
                    isStarting = false
                }
            }
            do {
                try await cameraManager.start()
                guard cameraLifecycle.isCurrent(generation) else {
                    await cameraManager.stop()
                    return
                }
                isRunning = true
                cursorCoordinator.setCameraRunning(true)
                airKeyboardCoordinator.setCameraRunning(true)
                status = "Looking for a hand…"
            } catch {
                guard cameraLifecycle.isCurrent(generation) else {
                    await cameraManager.stop()
                    return
                }
                status = error.localizedDescription
            }
        }
    }

    func stopCamera() {
        guard isRunning || isStarting, !isStopping else { return }
        let generation = cameraLifecycle.invalidate()
        let pendingStart = cameraStartTask
        pendingStart?.cancel()
        airKeyboardCoordinator.setCameraRunning(false)
        cursorCoordinator.setCameraRunning(false)
        cursorControlEnabled = false
        UserDefaults.standard.set(false, forKey: "cursorControlEnabled")
        isStarting = false
        isRunning = false
        isStopping = true
        status = "Stopping camera…"
        Task { [weak self] in
            guard let self else { return }
            if let pendingStart {
                await pendingStart.value
            }
            await cameraManager.stop()
            guard cameraLifecycle.isCurrent(generation) else { return }
            cameraStartTask = nil
            isStopping = false
            joints = []
            windowGestureMode = .idle
            windowTarget = "No window selected"
            framesPerSecond = 0
            inferenceMilliseconds = 0
            cpuUsagePercent = 0
            status = "Camera stopped"
        }
    }

    @discardableResult
    func setCursorControlEnabled(_ enabled: Bool) -> Bool {
        guard !enabled || isRunning else {
            status = "Start the camera before enabling cursor control."
            return false
        }
        if cursorCoordinator.setEnabled(enabled) {
            cursorControlEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: "cursorControlEnabled")
            accessibilityAuthorized = cursorCoordinator.isAccessibilityTrusted
            status = enabled ? "Cursor control active · Esc to stop" : "Cursor control stopped"
            return true
        } else {
            cursorControlEnabled = false
            gestureStatus = .trackingLost
            UserDefaults.standard.set(false, forKey: "cursorControlEnabled")
            accessibilityAuthorized = cursorCoordinator.isAccessibilityTrusted
            status = accessibilityAuthorized
                ? "Start the camera before enabling cursor control."
                : "Allow AirControl in System Settings → Privacy & Security → Accessibility."
            return false
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
        airKeyboardCoordinator.deactivate()
        cursorCoordinator.emergencyStop()
        cursorControlEnabled = false
        gestureStatus = .trackingLost
        windowGestureMode = .idle
        windowTarget = "No window selected"
        windowControlStatus = "Emergency stop · all gesture controls are off."
    }
}
