import CoreGraphics
import Foundation

final class CursorControlCoordinator: @unchecked Sendable {
    static let shared = CursorControlCoordinator()

    private let processingQueue = DispatchQueue(label: "aircontrol.cursor.processing", qos: .userInteractive)
    private let cursorController = CursorController()
    private var gestureRecognizer = GestureRecognizer()
    private var cameraIsRunning = false
    private var isEnabled = false

    var isAccessibilityTrusted: Bool { cursorController.isAccessibilityTrusted }

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
            let multiplier = min(max(pinchSensitivity, 0.6), 1.4)
            let configuration = GestureConfiguration(
                pinchStartThreshold: 0.32 * multiplier,
                pinchReleaseThreshold: 0.48 * multiplier,
                dragStartDelay: dragDelay
            )
            let actions = gestureRecognizer.process(
                joints: joints,
                timestamp: ProcessInfo.processInfo.systemUptime,
                configuration: configuration
            )
            for action in actions {
                handle(action, sensitivity: sensitivity, smoothing: smoothing)
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
        }
    }

    private func stopControl() {
        _ = gestureRecognizer.resetForTrackingLoss()
        isEnabled = false
        cursorController.stop()
    }
}
