import CoreGraphics
import Testing
@testable import AirControl

struct WindowGeometryTests {
    @Test
    func handDeltaMapsVisionCoordinatesToAccessibilityScreenCoordinates() {
        let delta = WindowGeometry.handDelta(
            from: CGPoint(x: 0.2, y: 0.3),
            to: CGPoint(x: 0.4, y: 0.5),
            displayBounds: CGRect(x: -100, y: 0, width: 1_000, height: 800),
            sensitivity: 0.5
        )

        #expect(delta.x == 100)
        #expect(delta.y == -80)
    }

    @Test
    func resizePreservesCenterAndClampsMinimumMaximumAndDisplay() {
        let frame = WindowFrame(originX: 700, originY: 500, width: 400, height: 300)
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 800)
        let minimum = WindowGeometry.resized(
            frame,
            scale: 0.1,
            minimumSize: CGSize(width: 250, height: 180),
            maximumSize: CGSize(width: 800, height: 700),
            displayBounds: bounds
        )
        let maximum = WindowGeometry.resized(
            frame,
            scale: 4,
            minimumSize: CGSize(width: 250, height: 180),
            maximumSize: CGSize(width: 800, height: 700),
            displayBounds: bounds
        )

        #expect(minimum.width == 250)
        #expect(minimum.height == 180)
        #expect(maximum.width == 800)
        #expect(maximum.height == 700)
        #expect(maximum.originX >= bounds.minX)
        #expect(maximum.originY >= bounds.minY)
        #expect(maximum.originX + maximum.width <= bounds.maxX)
        #expect(maximum.originY + maximum.height <= bounds.maxY)
    }

    @Test
    func accessibilityDisplayBoundsConvertSecondaryDisplaysToTopLeftCoordinates() {
        let bounds = WindowGeometry.accessibilityDisplayBounds(
            screenFrames: [
                CGRect(x: 0, y: 0, width: 1_000, height: 800),
                CGRect(x: 1_000, y: 100, width: 800, height: 600)
            ],
            primaryScreenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
        )

        #expect(bounds == CGRect(x: 0, y: 0, width: 1_800, height: 800))
    }

    @Test
    func windowControlRequiresAccessibilityAndAtLeastOneSettableAttribute() {
        #expect(WindowPermissionGate.allowsWindowControl(isTrusted: true, positionSettable: true, sizeSettable: false))
        #expect(!WindowPermissionGate.allowsWindowControl(isTrusted: false, positionSettable: true, sizeSettable: true))
        #expect(!WindowPermissionGate.allowsWindowControl(
            isTrusted: true,
            positionSettable: false,
            sizeSettable: false
        ))
    }
}

struct TwoHandResizeTrackerTests {
    @Test
    func distanceIncreaseExpandsAndCrossedHandsStopResize() {
        var tracker = TwoHandResizeTracker()
        #expect(tracker.begin([CGPoint(x: 0.3, y: 0.5), CGPoint(x: 0.7, y: 0.5)]) != nil)
        let scale = tracker.scale(for: [CGPoint(x: 0.25, y: 0.5), CGPoint(x: 0.75, y: 0.5)])
        let crossed = tracker.scale(for: [CGPoint(x: 0.8, y: 0.5), CGPoint(x: 0.2, y: 0.5)])

        #expect(scale.map { $0 > 1 } == true)
        #expect(crossed == nil)
    }

    @Test
    func losingOneHandStopsResizeStateImmediately() {
        var recognizer = WindowGestureRecognizer()
        let configuration = WindowGestureConfiguration(
            enabled: true,
            windowControlEnabled: true,
            twoHandResizeEnabled: true
        )
        _ = recognizer.process(hands: [openHand(centerX: 0.3)], timestamp: 1, configuration: configuration)
        _ = recognizer.process(hands: [openHand(centerX: 0.3)], timestamp: 1.8, configuration: configuration)
        let began = recognizer.process(
            hands: [openHand(centerX: 0.3), openHand(centerX: 0.7)],
            timestamp: 2,
            configuration: configuration
        )
        let lostHand = recognizer.process(hands: [openHand(centerX: 0.3)], timestamp: 2.1, configuration: configuration)
        #expect(began.mode == .windowResizing)
        #expect(lostHand.actions == [.endResizing])
        #expect(lostHand.mode == .windowControl)
    }

    @Test
    func palmHoldEntersControlAndFistHoldExitsIt() {
        var recognizer = WindowGestureRecognizer()
        let configuration = WindowGestureConfiguration(enabled: true, windowControlEnabled: true)
        _ = recognizer.process(hands: [openHand()], timestamp: 1, configuration: configuration)
        let entered = recognizer.process(hands: [openHand()], timestamp: 1.75, configuration: configuration)
        _ = recognizer.process(hands: [fistHand()], timestamp: 2, configuration: configuration)
        let exited = recognizer.process(hands: [fistHand()], timestamp: 2.95, configuration: configuration)

        #expect(entered.actions == [.enterWindowControl])
        #expect(entered.suppressCursor)
        #expect(exited.actions == [.exitWindowControl])
        #expect(exited.mode == .idle)
    }

    @Test
    func rejectedWindowEntryWaitsForPalmReleaseBeforeRetrying() {
        var recognizer = WindowGestureRecognizer()
        let configuration = WindowGestureConfiguration(enabled: true, windowControlEnabled: true)
        _ = recognizer.process(hands: [openHand()], timestamp: 1, configuration: configuration)
        let entry = recognizer.process(hands: [openHand()], timestamp: 1.75, configuration: configuration)
        recognizer.rejectWindowControlUntilRelease()

        let held = recognizer.process(hands: [openHand()], timestamp: 3, configuration: configuration)
        let released = recognizer.process(hands: [fistHand()], timestamp: 3.1, configuration: configuration)
        _ = recognizer.process(hands: [openHand()], timestamp: 4, configuration: configuration)
        let retried = recognizer.process(hands: [openHand()], timestamp: 4.75, configuration: configuration)

        #expect(entry.actions == [.enterWindowControl])
        #expect(held.actions.isEmpty)
        #expect(held.suppressCursor)
        #expect(released.mode == .cursorControl)
        #expect(retried.actions == [.enterWindowControl])
    }

    @Test
    func threeFingerSwipeSwitchesAppsWithoutEnteringWindowMode() {
        var recognizer = WindowGestureRecognizer()
        let configuration = WindowGestureConfiguration(enabled: true, appSwitchEnabled: true)
        _ = recognizer.process(hands: [threeFingerHand(centerX: 0.35)], timestamp: 1, configuration: configuration)
        let switched = recognizer.process(
            hands: [threeFingerHand(centerX: 0.55)],
            timestamp: 1.25,
            configuration: configuration
        )

        #expect(switched.actions == [.switchApp(direction: -1)])
        #expect(switched.mode == .cursorControl)
    }

    @Test
    func indexThumbPinchMovesWindowAndReleaseStopsIt() {
        var recognizer = WindowGestureRecognizer()
        let configuration = WindowGestureConfiguration(enabled: true, windowControlEnabled: true)
        _ = recognizer.process(hands: [openHand()], timestamp: 1, configuration: configuration)
        _ = recognizer.process(hands: [openHand()], timestamp: 1.8, configuration: configuration)
        let began = recognizer.process(hands: [pinchHand(centerX: 0.5)], timestamp: 2, configuration: configuration)
        let moved = recognizer.process(hands: [pinchHand(centerX: 0.65)], timestamp: 2.1, configuration: configuration)
        let ended = recognizer.process(hands: [releasedPinchHand()], timestamp: 2.2, configuration: configuration)

        #expect(began.actions == [.beginMoving(anchor: CGPoint(x: 0.46, y: 0.6))])
        #expect(moved.actions.contains { if case .moveWindow = $0 { true } else { false } })
        #expect(ended.actions == [.endMoving])
        #expect(ended.mode == .windowControl)
    }

    @Test
    func trackingLossEndsWindowMoveAndLeavesControlMode() {
        var recognizer = WindowGestureRecognizer()
        let configuration = WindowGestureConfiguration(enabled: true, windowControlEnabled: true)
        _ = recognizer.process(hands: [openHand()], timestamp: 1, configuration: configuration)
        _ = recognizer.process(hands: [openHand()], timestamp: 1.8, configuration: configuration)
        _ = recognizer.process(hands: [pinchHand(centerX: 0.5)], timestamp: 2, configuration: configuration)
        let lost = recognizer.process(hands: [], timestamp: 2.1, configuration: configuration)

        #expect(lost.actions == [.endMoving, .exitWindowControl])
        #expect(lost.mode == .idle)
    }

    @Test
    func cursorGestureIsSuppressedDuringWindowMode() {
        var recognizer = WindowGestureRecognizer()
        let configuration = WindowGestureConfiguration(enabled: true, windowControlEnabled: true)
        _ = recognizer.process(hands: [openHand()], timestamp: 1, configuration: configuration)
        let result = recognizer.process(hands: [openHand()], timestamp: 1.8, configuration: configuration)

        #expect(result.suppressCursor)
        #expect(result.mode == .windowControl)
    }

    private func openHand(centerX: Double = 0.5) -> [HandJoint] {
        hand(centerX: centerX, tipOffset: 0.3, thumbOffset: -0.2)
    }

    private func fistHand() -> [HandJoint] {
        hand(centerX: 0.5, tipOffset: 0.03, thumbOffset: -0.03)
    }

    private func pinchHand(centerX: Double) -> [HandJoint] {
        hand(centerX: centerX, tipOffset: 0.3, thumbOffset: 0.02).map { joint in
            guard joint.name == "thumbTip" else { return joint }
            return HandJoint(
                name: joint.name,
                normalizedX: joint.normalizedX,
                normalizedY: 0.6,
                confidence: joint.confidence
            )
        }
    }

    private func releasedPinchHand() -> [HandJoint] {
        hand(centerX: 0.5, tipOffset: 0.3, thumbOffset: 0.2).map { joint in
            guard joint.name == "thumbTip" else { return joint }
            return HandJoint(
                name: joint.name,
                normalizedX: joint.normalizedX,
                normalizedY: 0.6,
                confidence: joint.confidence
            )
        }
    }

    private func threeFingerHand(centerX: Double) -> [HandJoint] {
        hand(centerX: centerX, tipOffset: 0.3, thumbOffset: -0.2).filter { !$0.name.contains("little") }
    }

    private func hand(centerX: Double, tipOffset: Double, thumbOffset: Double) -> [HandJoint] {
        let fingers = ["index", "middle", "ring", "little"]
        let joints = fingers.enumerated().flatMap { index, finger in
            let horizontalPosition = centerX + Double(index - 1) * 0.04
            return [
                HandJoint(name: "\(finger)MCP", normalizedX: horizontalPosition, normalizedY: 0.3, confidence: 1),
                HandJoint(
                    name: "\(finger)Tip",
                    normalizedX: horizontalPosition,
                    normalizedY: 0.3 + tipOffset,
                    confidence: 1
                )
            ]
        }
        return joints + [
            HandJoint(name: "wrist", normalizedX: centerX, normalizedY: 0.1, confidence: 1),
            HandJoint(name: "thumbTip", normalizedX: centerX + thumbOffset, normalizedY: 0.3, confidence: 1),
            HandJoint(name: "indexTip", normalizedX: centerX, normalizedY: 0.3 + tipOffset, confidence: 1)
        ]
    }
}
