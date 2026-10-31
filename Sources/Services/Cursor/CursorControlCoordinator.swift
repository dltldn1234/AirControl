import CoreGraphics
import Foundation

enum CursorGestureInputGate {
    static func allowsInput(cameraIsRunning: Bool, airKeyboardIsActive: Bool) -> Bool {
        cameraIsRunning && !airKeyboardIsActive
    }
}

final class CursorControlCoordinator: @unchecked Sendable {
    static let shared = CursorControlCoordinator()

    private let processingQueue = DispatchQueue(label: "aircontrol.cursor.processing", qos: .userInteractive)
    private let cursorController = CursorController()
    private let windowCoordinator = WindowControlCoordinator()
    private var gestureRecognizer = GestureRecognizer()
    private var cameraIsRunning = false
    private var isEnabled = false
    private var isAirKeyboardActive = false
    private var lastUIUpdate = Date.distantPast
    private var gestureStatusHandler: ((ActiveGesture) -> Void)?
    private var calibration = CursorCalibrationProfile.load()

    var isAccessibilityTrusted: Bool { cursorController.isAccessibilityTrusted }
    var isWindowControlAccessibilityTrusted: Bool { windowCoordinator.isAccessibilityTrusted }

    func setGestureStatusHandler(_ handler: ((ActiveGesture) -> Void)?) {
        processingQueue.async { [weak self] in self?.gestureStatusHandler = handler }
    }

    func setWindowStatusHandler(_ handler: ((WindowGestureMode, String, String) -> Void)?) {
        processingQueue.async { [weak self] in self?.windowCoordinator.setStatusHandler(handler) }
    }

    func requestAccessibilityAccess() -> Bool {
        cursorController.requestAccessibilityAccess()
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if enabled, !cursorController.isAccessibilityTrusted {
            _ = cursorController.requestAccessibilityAccess()
            return false
        }
        return processingQueue.sync {
            guard !enabled || cameraIsRunning else { return false }
            isEnabled = enabled
            if enabled {
                _ = cursorController.setEnabled(true)
                gestureRecognizer = GestureRecognizer()
            } else {
                stopControl()
            }
            return true
        }
    }

    func setCameraRunning(_ running: Bool) {
        processingQueue.sync {
            cameraIsRunning = running
            if !running {
                windowCoordinator.stop()
                stopControl()
            }
        }
    }

    func setAirKeyboardActive(_ active: Bool) {
        processingQueue.sync {
            guard isAirKeyboardActive != active else { return }
            isAirKeyboardActive = active
            if active {
                let actions = gestureRecognizer.resetForTrackingLoss()
                if actions.contains(.endDrag) { cursorController.endDrag() }
                windowCoordinator.stop(message: "Air Keyboard active; cursor and window gestures are paused.")
            } else {
                gestureRecognizer = GestureRecognizer()
                windowCoordinator.stop(message: "Air Keyboard inactive; gesture controls are available.")
            }
        }
    }

    func processFrame(_ joints: [HandJoint]) {
        processFrame([joints])
    }

    func processFrame(_ hands: [[HandJoint]]) {
        processingQueue.async { [weak self] in
            guard let self,
                  CursorGestureInputGate.allowsInput(
                    cameraIsRunning: cameraIsRunning,
                    airKeyboardIsActive: isAirKeyboardActive
                  ) else { return }
            let suppressCursor = windowCoordinator.processFrame(
                hands,
                timestamp: ProcessInfo.processInfo.systemUptime
            )
            guard !suppressCursor, isEnabled, let joints = hands.first else { return }
            let settings = UserDefaults.standard
            processCursorFrame(joints, settings: settings)
        }
    }

    private func processCursorFrame(_ joints: [HandJoint], settings: UserDefaults) {
        let sensitivity = settings.object(forKey: "cursorSensitivity") as? Double ?? 1
        let smoothing = settings.object(forKey: "cursorSmoothing") as? Double ?? 0.4
        let multiplier = min(max(settings.object(forKey: "pinchSensitivity") as? Double ?? 1, 0.6), 1.4)
        let calibration = CursorCalibrationProfile.load(from: settings)
        self.calibration = calibration
        let configuration = GestureConfiguration(
            pinchStartThreshold: calibration.pinchStartThreshold * multiplier,
            pinchReleaseThreshold: calibration.pinchReleaseThreshold * multiplier,
            dragStartDelay: settings.object(forKey: "dragStartDelay") as? Double ?? 0.45,
            scrollSensitivity: settings.object(forKey: "scrollSensitivity") as? Double ?? 1,
            reversesScrollDirection: settings.bool(forKey: "reversesScrollDirection"),
            rightClickEnabled: settings.object(forKey: "rightClickEnabled") as? Bool ?? true,
            rightClickGestureEnabled: settings.object(forKey: "rightClickGestureEnabled") as? Bool ?? true,
            cursorEnabled: settings.object(forKey: "gestureCursorEnabled") as? Bool ?? true,
            leftClickEnabled: settings.object(forKey: "leftClickEnabled") as? Bool ?? true,
            dragEnabled: settings.object(forKey: "dragEnabled") as? Bool ?? true,
            scrollEnabled: settings.object(forKey: "scrollEnabled") as? Bool ?? true,
            scrollGestureEnabled: settings.object(forKey: "scrollGestureEnabled") as? Bool ?? true
        )
        let actions = gestureRecognizer.process(
            joints: joints,
            timestamp: ProcessInfo.processInfo.systemUptime,
            configuration: configuration
        )
        actions.forEach { handle($0, sensitivity: sensitivity, smoothing: smoothing) }
        guard Date().timeIntervalSince(lastUIUpdate) >= 0.1 else { return }
        lastUIUpdate = Date()
        let state = gestureRecognizer.activeGesture
        DispatchQueue.main.async { [weak self] in self?.gestureStatusHandler?(state) }
    }

    func stop() {
        processingQueue.sync {
            isEnabled = false
            cameraIsRunning = false
            windowCoordinator.stop(message: "App stopped; window control ended.")
            stopControl()
        }
    }

    func emergencyStop() {
        processingQueue.sync {
            UserDefaults.standard.set(false, forKey: "cursorControlEnabled")
            UserDefaults.standard.set(false, forKey: "windowControlEnabled")
            UserDefaults.standard.set(false, forKey: "appSwitchEnabled")
            isEnabled = false
            windowCoordinator.stop(message: "Emergency stop · all gesture controls are off.")
            stopControl()
        }
    }

    private func handle(_ action: GestureAction, sensitivity: Double, smoothing: Double) {
        switch action {
        case let .move(normalizedX, normalizedY):
            let bounds = DisplayCoordinateMapper.virtualBounds(
                for: DisplayCoordinateMapper.activeDisplayBounds()
            )
            let point = CursorCoordinateMapper.map(
                normalizedX: normalizedX,
                normalizedY: normalizedY,
                displayBounds: bounds,
                activeArea: calibration.activeArea.cgRect,
                mirrored: calibration.mirrorsCamera,
                sensitivity: sensitivity
            )
            cursorController.move(to: point, alpha: 1 - smoothing)
        case .click:
            cursorController.click()
        case .beginDrag:
            cursorController.beginDrag()
        case .endDrag:
            cursorController.endDrag()
        case .rightClick:
            cursorController.rightClick()
        case let .scroll(delta):
            cursorController.scroll(delta: delta * 1_800)
        }
    }

    private func stopControl() {
        _ = gestureRecognizer.resetForTrackingLoss()
        isEnabled = false
        cursorController.stop()
    }
}
