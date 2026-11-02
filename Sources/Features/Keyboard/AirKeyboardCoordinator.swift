import AppKit
import Combine
import Foundation

@MainActor
final class AirKeyboardCoordinator: ObservableObject {
    static let shared = AirKeyboardCoordinator()

    @Published private(set) var isActive = false
    @Published private(set) var interactionState = AirKeyboardInteractionState.inactive
    @Published private(set) var hoveredKeyID: String?
    @Published private(set) var statusMessage = "Air Keyboard is off."
    @Published private(set) var isShifted = false
    @Published private(set) var layoutLanguage: AirKeyboardLanguage

    private let inputEngine = AirKeyboardInputEngine()
    private let cursorCoordinator = CursorControlCoordinator.shared
    private let keyboardWindow = FloatingKeyboardWindow()
    private var recognizer = AirKeyboardGestureRecognizer()
    private var inputSensitivity = 1.0
    private var cameraIsRunning = false
    private var wasHandTracked = false

    var rows: [[AirKeyboardKey]] { AirKeyboardLayout.rows(for: layoutLanguage, shifted: isShifted) }
    var isAccessibilityTrusted: Bool { inputEngine.isAccessibilityTrusted }
    var canActivate: Bool { cameraIsRunning }

    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "airKeyboardLanguage")
            ?? AirKeyboardLanguage.english.rawValue
        layoutLanguage = AirKeyboardLanguage(rawValue: savedLanguage) ?? .english
        inputSensitivity = UserDefaults.standard.object(forKey: "airKeyboardSensitivity") as? Double ?? 1
    }

    func setCameraRunning(_ running: Bool) {
        cameraIsRunning = running
        if !running { deactivate() }
    }

    func activate() {
        guard !isActive else { return }
        guard cameraIsRunning else {
            statusMessage = "Start the camera before enabling Air Keyboard."
            return
        }
        guard inputEngine.isAccessibilityTrusted else {
            statusMessage = "Allow AirControl in System Settings → Privacy & Security → Accessibility."
            return
        }
        inputEngine.setEnabled(true)
        isActive = true
        wasHandTracked = false
        UserDefaults.standard.set(true, forKey: "airKeyboardEnabled")
        recognizer.setActive(true)
        cursorCoordinator.setAirKeyboardActive(true)
        let scale = UserDefaults.standard.object(forKey: "airKeyboardScale") as? Double ?? 1
        let opacity = UserDefaults.standard.object(forKey: "airKeyboardOpacity") as? Double ?? 0.94
        keyboardWindow.show(coordinator: self, scale: scale, opacity: opacity)
        statusMessage = "Air Keyboard active · cursor and window gestures paused."
        publish(recognizerResult: nil)
    }

    func deactivate() {
        guard isActive else { return }
        inputEngine.setEnabled(false)
        isActive = false
        wasHandTracked = false
        UserDefaults.standard.set(false, forKey: "airKeyboardEnabled")
        recognizer.setActive(false)
        inputEngine.releaseModifiers()
        isShifted = false
        hoveredKeyID = nil
        interactionState = .inactive
        cursorCoordinator.setAirKeyboardActive(false)
        keyboardWindow.hide()
        statusMessage = "Air Keyboard is off."
    }

    func stop() {
        deactivate()
        keyboardWindow.hideImmediately()
    }

    func processFrame(_ hands: [[HandJoint]]) {
        guard isActive else { return }
        guard let keyboardFrame = keyboardWindow.keyboardSurfaceFrame,
              let screenFrame = keyboardWindow.screenFrame else {
            handleTrackingLoss()
            return
        }
        let result = recognizer.process(
            hands: hands,
            rows: rows,
            keyboardFrame: keyboardFrame,
            screenFrame: screenFrame,
            sensitivity: inputSensitivity,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        if result.isHandTracked {
            if !wasHandTracked {
                statusMessage = "Hand tracking active · hover a key and pinch to type."
            }
            wasHandTracked = true
        } else {
            if wasHandTracked {
                handleTrackingLoss()
                statusMessage = "Hand tracking lost · keyboard input paused."
            }
            wasHandTracked = false
        }
        publish(recognizerResult: result)
        if let keyID = result.activatedKeyID,
           let key = rows.joined().first(where: { $0.id == keyID }) {
            perform(key.action)
        }
    }

    func setLanguage(_ language: AirKeyboardLanguage) {
        layoutLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "airKeyboardLanguage")
    }

    func updateSettings(scale: Double, opacity: Double, sensitivity: Double, language: AirKeyboardLanguage) {
        inputSensitivity = min(max(sensitivity, 0.6), 1.6)
        setLanguage(language)
        keyboardWindow.updateAppearance(scale: scale, opacity: opacity)
    }

    func resetKeyboardPosition() {
        keyboardWindow.resetPosition()
    }

    func activateManually(_ key: AirKeyboardKey) {
        guard isActive else { return }
        perform(key.action)
    }

    private func handleTrackingLoss() {
        recognizer.reset()
        inputEngine.releaseModifiers()
        isShifted = false
        hoveredKeyID = nil
        interactionState = .active
    }

    private func perform(_ action: AirKeyboardAction) {
        switch action {
        case .shift:
            isShifted.toggle()
            statusMessage = isShifted ? "Shift is on." : "Shift is off."
        case .inputSourceToggle:
            send(action, shifted: false, successMessage: "Input source switch shortcut sent.") { [weak self] in
                guard let self else { return }
                self.layoutLanguage = self.layoutLanguage == .english ? .korean : .english
                UserDefaults.standard.set(self.layoutLanguage.rawValue, forKey: "airKeyboardLanguage")
            }
        case .capsLock:
            send(action, shifted: false, successMessage: "Caps Lock key sent.")
        default:
            let shifted = isShifted
            isShifted = false
            send(action, shifted: shifted, successMessage: "Key sent.")
        }
    }

    private func send(
        _ action: AirKeyboardAction,
        shifted: Bool,
        successMessage: String,
        onSuccess: (() -> Void)? = nil
    ) {
        inputEngine.send(action, shifted: shifted) { [weak self] succeeded in
            guard let self, self.isActive else { return }
            guard succeeded else {
                self.statusMessage = "Keyboard event was not sent. Check Accessibility access or target field."
                return
            }
            onSuccess?()
            self.statusMessage = successMessage
        }
    }

    private func publish(recognizerResult: AirKeyboardGestureResult?) {
        guard let recognizerResult else {
            if interactionState != .active { interactionState = .active }
            if hoveredKeyID != nil { hoveredKeyID = nil }
            return
        }
        if interactionState != recognizerResult.state { interactionState = recognizerResult.state }
        if hoveredKeyID != recognizerResult.hoveredKeyID { hoveredKeyID = recognizerResult.hoveredKeyID }
    }
}
