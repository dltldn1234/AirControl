import Foundation
import XCTest
@testable import AirControl

final class SettingsBackupTests: XCTestCase {
    func testExportAndImportRoundTripOnlyAirControlOwnedSettings() throws {
        let suiteName = "AirControlSettingsBackupTests.\(UUID().uuidString)"
        let sourceDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { sourceDefaults.removePersistentDomain(forName: suiteName) }
        sourceDefaults.set(1.7, forKey: "cursorSensitivity")
        sourceDefaults.set("drag", forKey: "indexPinchActionMapping")
        sourceDefaults.set("private-camera-frame", forKey: "unrelatedCameraData")
        var profile = CursorCalibrationProfile()
        profile.activeArea = NormalizedCursorArea(originX: 0.1, originY: 0.12, width: 0.8, height: 0.78)
        profile.isCalibrated = true
        profile.save(to: sourceDefaults)

        let backup = AirControlSettingsBackup(defaults: sourceDefaults)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AirControl-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try backup.write(to: fileURL)
        let loaded = try AirControlSettingsBackup.read(from: fileURL)
        let json = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertEqual(loaded, backup)
        XCTAssertFalse(json.contains("unrelatedCameraData"))
        XCTAssertFalse(json.contains("private-camera-frame"))
    }

    func testImportClampsValuesFiltersUnknownKeysAndDisablesSystemInput() throws {
        let suiteName = "AirControlSettingsBackupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "cursorControlEnabled")
        defaults.set(true, forKey: "airKeyboardEnabled")

        let backup = AirControlSettingsBackup(
            doubles: ["cursorSensitivity": 100, "unknownPreference": 2],
            booleans: ["rightClickEnabled": false, "unknownFlag": true],
            strings: ["airKeyboardLanguage": "invalid", "indexPinchActionMapping": "drag"],
            calibration: CursorCalibrationProfile()
        )

        try backup.apply(to: defaults)

        XCTAssertEqual(defaults.double(forKey: "cursorSensitivity"), 2)
        XCTAssertFalse(defaults.bool(forKey: "rightClickEnabled"))
        XCTAssertNil(defaults.object(forKey: "unknownPreference"))
        XCTAssertNil(defaults.object(forKey: "unknownFlag"))
        XCTAssertEqual(defaults.string(forKey: "airKeyboardLanguage"), AirKeyboardLanguage.english.rawValue)
        XCTAssertEqual(defaults.string(forKey: "indexPinchActionMapping"), PinchActionMapping.drag.rawValue)
        XCTAssertFalse(defaults.bool(forKey: "cursorControlEnabled"))
        XCTAssertFalse(defaults.bool(forKey: "airKeyboardEnabled"))
        XCTAssertFalse(defaults.bool(forKey: "windowControlEnabled"))
        XCTAssertFalse(defaults.bool(forKey: "appSwitchEnabled"))
    }

    func testImportRejectsUnknownSchemaVersion() throws {
        let suiteName = "AirControlSettingsBackupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let backup = AirControlSettingsBackup(version: 99, doubles: [:], booleans: [:], strings: [:])

        XCTAssertThrowsError(try backup.apply(to: defaults))
    }
}
