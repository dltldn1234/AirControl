import XCTest
@testable import AirControl

final class CameraMetricsTests: XCTestCase {
    func testCameraPermissionGateAllowsOnlyAuthorizedState() {
        XCTAssertTrue(CameraPermissionGate.allowsCapture(for: .authorized))
        XCTAssertFalse(CameraPermissionGate.allowsCapture(for: .denied))
        XCTAssertFalse(CameraPermissionGate.allowsCapture(for: .restricted))
        XCTAssertFalse(CameraPermissionGate.allowsCapture(for: .notDetermined))
    }

    func testCameraSelectionPrefersSavedDeviceAndFallsBackSafely() {
        XCTAssertEqual(
            CameraDeviceSelection.resolve(
                preferredID: "external",
                availableIDs: ["built-in", "external"],
                frontCameraID: "built-in"
            ),
            "external"
        )
        XCTAssertEqual(
            CameraDeviceSelection.resolve(
                preferredID: "disconnected",
                availableIDs: ["external", "built-in"],
                frontCameraID: "built-in"
            ),
            "built-in"
        )
        XCTAssertEqual(
            CameraDeviceSelection.resolve(
                preferredID: nil,
                availableIDs: ["external"],
                frontCameraID: nil
            ),
            "external"
        )
        XCTAssertNil(CameraDeviceSelection.resolve(preferredID: nil, availableIDs: [], frontCameraID: nil))
    }

    func testCameraInterruptionReasonMapsToActionableStatus() {
        XCTAssertEqual(
            CameraManagerStatus.interruptionMessage,
            "Camera capture was interrupted by macOS."
        )
    }

    func testFramesPerSecondUsesElapsedFrameTime() {
        XCTAssertEqual(
            CameraFrameMetrics.framesPerSecond(previousFrameTime: 2, currentFrameTime: 2.05),
            20,
            accuracy: 0.0001
        )
    }

    func testFramesPerSecondHandlesFirstOrInvalidTimestamp() {
        XCTAssertEqual(CameraFrameMetrics.framesPerSecond(previousFrameTime: nil, currentFrameTime: 2), 0)
        XCTAssertEqual(CameraFrameMetrics.framesPerSecond(previousFrameTime: 2, currentFrameTime: 2), 0)
        XCTAssertEqual(CameraFrameMetrics.framesPerSecond(previousFrameTime: 3, currentFrameTime: 2), 0)
    }

    func testCpuPercentRejectsInvalidIntervalsAndCapsAtOneHundred() {
        XCTAssertNil(CameraFrameMetrics.cpuPercent(cpuTimeDelta: 0.1, wallTimeDelta: 0))
        XCTAssertNil(CameraFrameMetrics.cpuPercent(cpuTimeDelta: -.infinity, wallTimeDelta: 1))
        XCTAssertEqual(CameraFrameMetrics.cpuPercent(cpuTimeDelta: 2, wallTimeDelta: 1), 100)
        XCTAssertEqual(CameraFrameMetrics.cpuPercent(cpuTimeDelta: 0.25, wallTimeDelta: 1), 25)
    }
}
