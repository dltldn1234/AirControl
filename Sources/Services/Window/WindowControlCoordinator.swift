import Foundation

final class WindowControlCoordinator {
    private let windowManager = WindowManager()
    private let appSwitcher = RunningAppSwitcher()
    private var recognizer = WindowGestureRecognizer()
    private var statusHandler: ((WindowGestureMode, String, String) -> Void)?
    private var lastUIUpdate = 0.0
    private var statusMessage = ""
    private var targetDescription = "No window selected"

    var isAccessibilityTrusted: Bool { windowManager.isAccessibilityTrusted }

    func setStatusHandler(_ handler: ((WindowGestureMode, String, String) -> Void)?) {
        statusHandler = handler
    }

    @discardableResult
    func processFrame(_ hands: [[HandJoint]], timestamp: TimeInterval) -> Bool {
        let settings = UserDefaults.standard
        let windowEnabled = settings.bool(forKey: "windowControlEnabled")
        let appSwitchEnabled = settings.bool(forKey: "appSwitchEnabled")
        let trusted = windowManager.isAccessibilityTrusted
        let configuration = WindowGestureConfiguration(
            enabled: appSwitchEnabled || (windowEnabled && trusted),
            windowControlEnabled: windowEnabled && trusted,
            appSwitchEnabled: appSwitchEnabled,
            twoHandResizeEnabled: settings.bool(forKey: "twoHandResizeEnabled"),
            moveSensitivity: settings.object(forKey: "windowMoveSensitivity") as? Double ?? 1,
            resizeSmoothing: settings.object(forKey: "windowResizeSmoothing") as? Double ?? 0.25
        )
        if windowEnabled || appSwitchEnabled, !trusted {
            statusMessage = "Grant Accessibility access to control windows or switch apps."
        }
        let result = recognizer.process(hands: hands, timestamp: timestamp, configuration: configuration)
        result.actions.forEach(handle)
        publish(mode: result.mode)
        return result.suppressCursor
    }

    func stop(message: String = "Camera stopped; window control ended.") {
        _ = recognizer.reset()
        windowManager.endManipulation()
        windowManager.clearSelection()
        targetDescription = "No window selected"
        statusMessage = message
        publish(mode: .idle, force: true)
    }

    private func handle(_ action: WindowGestureAction) {
        switch action {
        case .enterWindowControl:
            enterWindowControl()
        case .exitWindowControl:
            windowManager.endManipulation()
            windowManager.clearSelection()
            targetDescription = "No window selected"
            statusMessage = "Window control stopped."
        case .beginMoving, .moveWindow, .endMoving:
            handleMove(action)
        case .beginResizing, .resizeWindow, .endResizing:
            handleResize(action)
        case let .switchApp(direction):
            guard let application = appSwitcher.activateNext(direction: direction) else {
                statusMessage = "No other visible application is running."
                return
            }
            windowManager.clearSelection()
            targetDescription = application.localizedName
            statusMessage = "Activation requested for \(application.localizedName)."
        }
    }

    private func enterWindowControl() {
        guard let target = windowManager.selectActiveWindow() else {
            statusMessage = windowManager.isAccessibilityTrusted
                ? "The active app does not expose a controllable window."
                : "Grant Accessibility access to control windows."
            targetDescription = "No window selected"
            recognizer.rejectWindowControlUntilRelease()
            return
        }
        updateTarget(target)
        statusMessage = "Window control active · hold a fist to exit."
    }

    private func handleMove(_ action: WindowGestureAction) {
        switch action {
        case let .beginMoving(anchor):
            guard let target = windowManager.beginMoving(at: anchor) else {
                failCurrentGesture("The active window cannot be moved.")
                return
            }
            updateTarget(target)
        case let .moveWindow(position, sensitivity):
            if let target = windowManager.moveSelectedWindow(to: position, sensitivity: sensitivity) {
                updateTarget(target)
            }
        case .endMoving:
            windowManager.endManipulation()
        default:
            break
        }
    }

    private func handleResize(_ action: WindowGestureAction) {
        switch action {
        case .beginResizing:
            guard let target = windowManager.beginResizing() else {
                failCurrentGesture("The active window cannot be resized.")
                return
            }
            updateTarget(target)
        case let .resizeWindow(scale, smoothing):
            if let target = windowManager.resizeSelectedWindow(fromScale: scale, smoothing: smoothing) {
                updateTarget(target)
            }
        case .endResizing:
            windowManager.endManipulation()
        default:
            break
        }
    }

    private func failCurrentGesture(_ message: String) {
        statusMessage = message
        recognizer.rejectWindowControlUntilRelease()
        windowManager.endManipulation()
        windowManager.clearSelection()
        targetDescription = "No window selected"
    }

    private func updateTarget(_ target: WindowTargetInfo) {
        targetDescription = "\(target.applicationName) · \(target.windowTitle)"
        statusMessage = "Window control active."
    }

    private func publish(mode: WindowGestureMode, force: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastUIUpdate >= 0.1 else { return }
        lastUIUpdate = now
        UserDefaults.standard.set(mode.rawValue, forKey: "windowGestureMode")
        UserDefaults.standard.set(targetDescription, forKey: "windowControlTarget")
        UserDefaults.standard.set(statusMessage, forKey: "windowControlStatus")
        let target = targetDescription
        let message = statusMessage
        DispatchQueue.main.async { [weak self] in self?.statusHandler?(mode, target, message) }
    }
}
