import XCTest
@testable import AirControl

final class CameraMetricsTests: XCTestCase {
    func testCameraPermissionGateAllowsOnlyAuthorizedState() {
        XCTAssertTrue(CameraPermissionGate.allowsCapture(for: .authorized))
        XCTAssertFalse(CameraPermissionGate.allowsCapture(for: .denied))
        XCTAssertFalse(CameraPermissionGate.allowsCapture(for: .restricted))
        XCTAssertFalse(CameraPermissionGate.allowsCapture(for: .notDetermined))
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
