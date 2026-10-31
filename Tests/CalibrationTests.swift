import CoreGraphics
import XCTest
@testable import AirControl

final class CalibrationTests: XCTestCase {
    func testActiveAreaUsesCapturedBoundsAndInset() throws {
        let area = try XCTUnwrap(
            CalibrationMath.activeArea(
                left: CGPoint(x: 0.1, y: 0.5),
                right: CGPoint(x: 0.9, y: 0.5),
                top: CGPoint(x: 0.5, y: 0.9),
                bottom: CGPoint(x: 0.5, y: 0.1)
            )
        )

        XCTAssertEqual(area.originX, 0.115, accuracy: 0.0001)
        XCTAssertEqual(area.originY, 0.115, accuracy: 0.0001)
        XCTAssertEqual(area.width, 0.77, accuracy: 0.0001)
        XCTAssertEqual(area.height, 0.77, accuracy: 0.0001)
        XCTAssertTrue(area.isValid)
    }

    func testActiveAreaRejectsInsufficientRange() {
        XCTAssertNil(
            CalibrationMath.activeArea(
                left: CGPoint(x: 0.4, y: 0.5),
                right: CGPoint(x: 0.55, y: 0.5),
                top: CGPoint(x: 0.5, y: 0.55),
                bottom: CGPoint(x: 0.5, y: 0.4)
            )
        )
    }

    func testPinchThresholdsSeparateStartAndRelease() throws {
        let thresholds = try XCTUnwrap(
            CalibrationMath.pinchThresholds(openDistance: 0.8, closedDistance: 0.2)
        )

        XCTAssertEqual(thresholds.start, 0.41, accuracy: 0.0001)
        XCTAssertEqual(thresholds.release, 0.53, accuracy: 0.0001)
        XCTAssertLessThan(thresholds.start, thresholds.release)
    }

    func testPinchThresholdsRejectUnusableSamples() {
        XCTAssertNil(CalibrationMath.pinchThresholds(openDistance: 0.3, closedDistance: 0.3))
        XCTAssertNil(CalibrationMath.pinchThresholds(openDistance: .nan, closedDistance: 0.1))
    }

    func testProfilePersistsAndReloadsFromUserDefaults() throws {
        let suiteName = "AirControlCalibrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var profile = CursorCalibrationProfile()
        profile.activeArea = NormalizedCursorArea(originX: 0.12, originY: 0.16, width: 0.75, height: 0.7)
        profile.pinchStartThreshold = 0.3
        profile.pinchReleaseThreshold = 0.46
        profile.mirrorsCamera = false
        profile.isCalibrated = true

        profile.save(to: defaults)

        XCTAssertEqual(CursorCalibrationProfile.load(from: defaults), profile)
        XCTAssertEqual(defaults.double(forKey: "cursorActiveAreaWidth"), 0.75, accuracy: 0.0001)
    }

    func testProfileDoesNotPersistInvalidArea() throws {
        let suiteName = "AirControlCalibrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var profile = CursorCalibrationProfile()
        profile.activeArea = NormalizedCursorArea(originX: 0.8, originY: 0.8, width: 0.4, height: 0.4)
        profile.isCalibrated = true

        profile.save(to: defaults)

        XCTAssertNil(defaults.data(forKey: "cursorCalibrationProfile"))
    }
}
