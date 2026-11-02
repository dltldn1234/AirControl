import ApplicationServices
import CoreGraphics
import Foundation

enum AirKeyboardKeyCode {
    static func code(for character: Character) -> (code: CGKeyCode, requiresShift: Bool)? {
        let plain: [Character: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47, "`": 50
        ]
        if let code = plain[character] { return (code, false) }
        if let lower = character.lowercased().first, let code = plain[lower], character.isUppercase {
            return (code, true)
        }
        let symbols: [Character: Character] = [
            "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6",
            "&": "7", "*": "8", "(": "9", ")": "0", "_": "-", "+": "=",
            "{": "[", "}": "]", "|": "\\", ":": ";", "\"": "'", "<": ",",
            ">": ".", "?": "/", "~": "`"
        ]
        guard let base = symbols[character], let code = plain[base] else { return nil }
        return (code, true)
    }
}

enum AirKeyboardPermissionGate {
    static func allowsInput(isActive: Bool, isTrusted: Bool, isSecureFieldFocused: Bool) -> Bool {
        isActive && isTrusted && !isSecureFieldFocused
    }
}

final class AirKeyboardInputEngine: @unchecked Sendable {
    private let eventQueue = DispatchQueue(label: "aircontrol.keyboard.events", qos: .userInteractive)
    private var isEnabled = false

    var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    func setEnabled(_ enabled: Bool) {
        eventQueue.sync { isEnabled = enabled }
    }

    func send(
        _ action: AirKeyboardAction,
        shifted: Bool = false,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        eventQueue.async { [weak self] in
            guard let self else { return }
            guard AirKeyboardPermissionGate.allowsInput(
                isActive: isEnabled,
                isTrusted: isAccessibilityTrusted,
                isSecureFieldFocused: isSecureTextFieldFocused
            ) else {
                Task { @MainActor in completion(false) }
                return
            }
            let result: Bool
            switch action {
            case let .character(character, keyRequiresShift):
                guard let mapping = AirKeyboardKeyCode.code(for: character) else {
                    Task { @MainActor in completion(false) }
                    return
                }
                let needsShift = shifted != (mapping.requiresShift != keyRequiresShift)
                result = postKey(mapping.code, flags: needsShift ? .maskShift : [])
            case .space:
                result = postKey(49, flags: shifted ? .maskShift : [])
            case .enter:
                result = postKey(36, flags: shifted ? .maskShift : [])
            case .backspace:
                result = postKey(51, flags: shifted ? .maskShift : [])
            case .capsLock:
                result = postKey(57, flags: [])
            case .inputSourceToggle:
                result = postKey(49, flags: .maskControl)
            case .shift:
                result = false
            }
            Task { @MainActor in completion(result) }
        }
    }

    func releaseModifiers() {
        // Modifier state is attached to each synthetic event pair rather than
        // held across frames, so tracking loss cannot leave a key physically down.
    }

    private func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private var isSecureTextFieldFocused: Bool {
        let systemElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return false }
        let focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)
        var subroleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSubroleAttribute as CFString,
            &subroleValue
        ) == .success,
              let subrole = subroleValue as? String else { return false }
        return subrole == kAXSecureTextFieldSubrole as String
            || subrole.localizedCaseInsensitiveContains("secure")
    }
}
