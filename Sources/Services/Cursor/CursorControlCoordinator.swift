import CoreGraphics
import Foundation

final class CursorControlCoordinator: @unchecked Sendable {
    static let shared = CursorControlCoordinator()

    private let processingQueue = DispatchQueue(label: "aircontrol.cursor.processing", qos: .userInteractive)
    private let cursorController = CursorController()
    private var gestureRecognizer = GestureRecognizer()
    private var cameraIsRunning = false
    private var isEnabled = false
    private var lastUIUpdate = Date.distantPast
    private var gestureStatusHandler: ((ActiveGesture) -> Void)?

    var isAccessibilityTrusted: Bool { cursorController.isAccessibilityTrusted }

    func setGestureStatusHandler(_ handler: ((ActiveGesture) -> Void)?) {
        processingQueue.async { [weak self] in self?.gestureStatusHandler = handler }
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
                stopControl()
            }
        }
    }

    func processFrame(_ joints: [HandJoint]) {
        processingQueue.async { [weak self] in
            guard let self, isEnabled else { return }
            let settings = UserDefaults.standard
            let sensitivity = settings.object(forKey: "cursorSensitivity") as? Double ?? 1
            let smoothing = settings.object(forKey: "cursorSmoothing") as? Double ?? 0.4
            let pinchSensitivity = settings.object(forKey: "pinchSensitivity") as? Double ?? 1
            let dragDelay = settings.object(forKey: "dragStartDelay") as? Double ?? 0.45
            let scrollSensitivity = settings.object(forKey: "scrollSensitivity") as? Double ?? 1
            let reversesScroll = settings.bool(forKey: "reversesScrollDirection")
            let rightClickEnabled = settings.object(forKey: "rightClickEnabled") as? Bool ?? true
            let leftClickEnabled = settings.object(forKey: "leftClickEnabled") as? Bool ?? true
            let dragEnabled = settings.object(forKey: "dragEnabled") as? Bool ?? true
            let scrollEnabled = settings.object(forKey: "scrollEnabled") as? Bool ?? true
            let cursorEnabled = settings.object(forKey: "gestureCursorEnabled") as? Bool ?? true
            let rightClickGestureEnabled = settings.object(forKey: "rightClickGestureEnabled") as? Bool ?? true
            let scrollGestureEnabled = settings.object(forKey: "scrollGestureEnabled") as? Bool ?? true
            let multiplier = min(max(pinchSensitivity, 0.6), 1.4)
            let configuration = GestureConfiguration(
                pinchStartThreshold: 0.32 * multiplier,
                pinchReleaseThreshold: 0.48 * multiplier,
                dragStartDelay: dragDelay,
                scrollSensitivity: scrollSensitivity,
                reversesScrollDirection: reversesScroll,
                rightClickEnabled: rightClickEnabled,
                rightClickGestureEnabled: rightClickGestureEnabled,
                cursorEnabled: cursorEnabled,
                leftClickEnabled: leftClickEnabled,
                dragEnabled: dragEnabled,
                scrollEnabled: scrollEnabled,
                scrollGestureEnabled: scrollGestureEnabled
            )
            let actions = gestureRecognizer.process(
                joints: joints,
                timestamp: ProcessInfo.processInfo.systemUptime,
                configuration: configuration
            )
            for action in actions {
                handle(action, sensitivity: sensitivity, smoothing: smoothing)
            }
            if Date().timeIntervalSince(lastUIUpdate) >= 0.1 {
                lastUIUpdate = Date()
                let state = gestureRecognizer.activeGesture
                DispatchQueue.main.async { [weak self] in self?.gestureStatusHandler?(state) }
            }
        }
    }

    func stop() {
        processingQueue.sync {
            isEnabled = false
            cameraIsRunning = false
            stopControl()
        }
    }

    private func handle(_ action: GestureAction, sensitivity: Double, smoothing: Double) {
        switch action {
        case let .move(normalizedX, normalizedY):
            let bounds = CGDisplayBounds(CGMainDisplayID())
            let point = CursorCoordinateMapper.map(
                normalizedX: normalizedX,
                normalizedY: normalizedY,
                displayBounds: bounds,
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
