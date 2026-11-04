import Foundation

struct AirControlSettingsBackup: Codable, Equatable {
    static let schemaVersion = 1

    static let doubleDefaults: [String: Double] = [
        "cursorSensitivity": 1,
        "cursorSmoothing": 0.4,
        "pinchSensitivity": 1,
        "gestureConfidenceThreshold": 0.55,
        "dragStartDelay": 0.45,
        "scrollSensitivity": 1,
        "windowMoveSensitivity": 1,
        "windowResizeSmoothing": 0.25,
        "airKeyboardScale": 1,
        "airKeyboardOpacity": 0.94,
        "airKeyboardSensitivity": 1
    ]

    static let doubleRanges: [String: ClosedRange<Double>] = [
        "cursorSensitivity": 0.5...2,
        "cursorSmoothing": 0...0.9,
        "pinchSensitivity": 0.6...1.4,
        "gestureConfidenceThreshold": 0.45...0.9,
        "dragStartDelay": 0.2...1,
        "scrollSensitivity": 0.4...3,
        "windowMoveSensitivity": 0.4...2,
        "windowResizeSmoothing": 0.05...0.8,
        "airKeyboardScale": 0.75...1.35,
        "airKeyboardOpacity": 0.5...1,
        "airKeyboardSensitivity": 0.6...1.6
    ]

    static let booleanDefaults: [String: Bool] = [
        "showsCameraPreview": true,
        "reversesScrollDirection": false,
        "rightClickEnabled": true,
        "gestureCursorEnabled": true,
        "leftClickEnabled": true,
        "dragEnabled": true,
        "scrollEnabled": true,
        "rightClickGestureEnabled": true,
        "airKeyboardFeedback": true
    ]

    static let stringDefaults: [String: String] = [
        "airKeyboardLanguage": AirKeyboardLanguage.english.rawValue,
        "indexPinchActionMapping": PinchActionMapping.leftClick.rawValue,
        "middlePinchActionMapping": PinchActionMapping.rightClick.rawValue
    ]

    let version: Int
    let doubles: [String: Double]
    let booleans: [String: Bool]
    let strings: [String: String]
    let calibration: CursorCalibrationProfile

    init(defaults: UserDefaults = .standard) {
        version = Self.schemaVersion
        doubles = Dictionary(uniqueKeysWithValues: Self.doubleDefaults.keys.map { key in
            (key, defaults.object(forKey: key) as? Double ?? Self.doubleDefaults[key] ?? 0)
        })
        booleans = Dictionary(uniqueKeysWithValues: Self.booleanDefaults.map { key, fallback in
            (key, defaults.object(forKey: key) as? Bool ?? fallback)
        })
        strings = Dictionary(uniqueKeysWithValues: Self.stringDefaults.map { key, fallback in
            (key, defaults.string(forKey: key) ?? fallback)
        })
        calibration = CursorCalibrationProfile.load(from: defaults)
    }

    init(
        version: Int = AirControlSettingsBackup.schemaVersion,
        doubles: [String: Double],
        booleans: [String: Bool],
        strings: [String: String],
        calibration: CursorCalibrationProfile = CursorCalibrationProfile()
    ) {
        self.version = version
        self.doubles = doubles
        self.booleans = booleans
        self.strings = strings
        self.calibration = calibration
    }

    func apply(to defaults: UserDefaults = .standard) throws {
        guard version == Self.schemaVersion else {
            throw AirControlSettingsBackupError.unsupportedVersion
        }
        for (key, value) in doubles {
            guard let range = Self.doubleRanges[key], value.isFinite else { continue }
            defaults.set(min(max(value, range.lowerBound), range.upperBound), forKey: key)
        }
        for (key, value) in booleans where Self.booleanDefaults[key] != nil {
            defaults.set(value, forKey: key)
        }
        for (key, fallback) in Self.stringDefaults {
            if let value = strings[key], Self.isValidString(value, forKey: key) {
                defaults.set(value, forKey: key)
            } else if let currentValue = defaults.string(forKey: key), Self.isValidString(currentValue, forKey: key) {
                continue
            } else {
                defaults.set(fallback, forKey: key)
            }
        }
        calibration.save(to: defaults)

        // Importing preferences must never start system input.
        defaults.set(false, forKey: "cursorControlEnabled")
        defaults.set(false, forKey: "airKeyboardEnabled")
        defaults.set(false, forKey: "windowControlEnabled")
        defaults.set(false, forKey: "appSwitchEnabled")
        defaults.set(false, forKey: "twoHandResizeEnabled")
    }

    static func read(from url: URL) throws -> AirControlSettingsBackup {
        let backup = try JSONDecoder().decode(AirControlSettingsBackup.self, from: Data(contentsOf: url))
        guard backup.version == schemaVersion else { throw AirControlSettingsBackupError.unsupportedVersion }
        return backup
    }

    func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    private static func isValidString(_ value: String, forKey key: String) -> Bool {
        switch key {
        case "airKeyboardLanguage":
            AirKeyboardLanguage(rawValue: value) != nil
        case "indexPinchActionMapping", "middlePinchActionMapping":
            PinchActionMapping(rawValue: value) != nil
        default:
            false
        }
    }
}

enum AirControlSettingsBackupError: LocalizedError {
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This AirControl settings file version is not supported."
        }
    }
}
