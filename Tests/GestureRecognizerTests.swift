import Testing
@testable import AirControl

struct GestureRecognizerTests {
    @Test
    func shortPinchCreatesOneClickAfterRelease() {
        var recognizer = GestureRecognizer()
        _ = recognizer.process(joints: hand(pinchDistance: 0.02), timestamp: 1)
        let actions = recognizer.process(joints: hand(pinchDistance: 0.08), timestamp: 1.1)

        #expect(actions.contains(.click))
        #expect(!recognizer.isPinching)
    }

    @Test
    func cursorMovementUsesConfidentIndexFingertip() {
        var recognizer = GestureRecognizer()
        let actions = recognizer.process(joints: hand(pinchDistance: 0.08), timestamp: 1)

        #expect(actions.contains(.move(normalizedX: 0.5, normalizedY: 0.6)))
    }

    @Test
    func lowConfidenceIndexTipPreventsCursorMovement() {
        var recognizer = GestureRecognizer()
        let joints = hand(pinchDistance: 0.08).map { joint in
            joint.name == "indexTip"
                ? HandJoint(
                    name: joint.name,
                    normalizedX: joint.normalizedX,
                    normalizedY: joint.normalizedY,
                    confidence: 0.4
                )
                : joint
        }

        let actions = recognizer.process(joints: joints, timestamp: 1)

        #expect(actions.isEmpty)
        #expect(recognizer.activeGesture == .trackingLost)
    }

    @Test
    func heldPinchStartsDragAndTrackingLossReleasesIt() {
        var recognizer = GestureRecognizer()
        _ = recognizer.process(joints: hand(pinchDistance: 0.02), timestamp: 1)
        let dragActions = recognizer.process(joints: hand(pinchDistance: 0.02), timestamp: 1.5)
        let lossActions = recognizer.process(joints: [], timestamp: 1.6)

        #expect(dragActions.contains(.beginDrag))
        #expect(lossActions == [.endDrag])
        #expect(!recognizer.isDragging)
    }

    @Test
    func rapidSecondPinchDoesNotCreateDuplicateClick() {
        var recognizer = GestureRecognizer()
        _ = recognizer.process(joints: hand(pinchDistance: 0.02), timestamp: 1)
        let firstRelease = recognizer.process(joints: hand(pinchDistance: 0.08), timestamp: 1.1)
        _ = recognizer.process(joints: hand(pinchDistance: 0.02), timestamp: 1.2)
        let secondRelease = recognizer.process(joints: hand(pinchDistance: 0.08), timestamp: 1.3)

        #expect(firstRelease.contains(.click))
        #expect(!secondRelease.contains(.click))
    }

    @Test
    func thumbMiddlePinchCreatesRightClickWithoutLeftClick() {
        var recognizer = GestureRecognizer()
        _ = recognizer.process(joints: hand(middlePinchDistance: 0.01), timestamp: 1)
        let actions = recognizer.process(joints: hand(middlePinchDistance: 0.08), timestamp: 1.1)

        #expect(actions == [.rightClick])
        #expect(!actions.contains(.click))
    }

    @Test
    func twoFingerVerticalMovementScrollsWithoutCursorMovement() {
        var recognizer = GestureRecognizer()
        _ = recognizer.process(joints: scrollHand(indexY: 0.6), timestamp: 1)
        let actions = recognizer.process(joints: scrollHand(indexY: 0.52), timestamp: 1.1)

        #expect(actions.contains { if case .scroll = $0 { true } else { false } })
        #expect(!actions.contains { if case .move = $0 { true } else { false } })
    }

    @Test
    func scrollDirectionCanBeReversedAndTrackingLossExitsScroll() {
        var recognizer = GestureRecognizer()
        var settings = GestureConfiguration()
        settings.reversesScrollDirection = true
        _ = recognizer.process(joints: scrollHand(indexY: 0.6), timestamp: 1, configuration: settings)
        let actions = recognizer.process(joints: scrollHand(indexY: 0.52), timestamp: 1.1, configuration: settings)
        let lossActions = recognizer.process(joints: [], timestamp: 1.2, configuration: settings)

        #expect(actions.contains { if case let .scroll(delta) = $0 { delta > 0 } else { false } })
        #expect(lossActions.isEmpty)
        #expect(recognizer.activeGesture == .trackingLost)
    }

    @Test
    func clickPinchDoesNotBecomeRightClickWhenFingerDistancesCross() {
        var recognizer = GestureRecognizer()
        _ = recognizer.process(joints: hand(pinchDistance: 0.02), timestamp: 1)
        let actions = recognizer.process(joints: hand(middlePinchDistance: 0.08), timestamp: 1.1)

        #expect(!actions.contains(.rightClick))
    }

    @Test
    func indexPinchCanBeMappedToRightClick() {
        var recognizer = GestureRecognizer()
        var configuration = GestureConfiguration()
        configuration.indexPinchMapping = .rightClick
        _ = recognizer.process(joints: hand(pinchDistance: 0.02), timestamp: 1, configuration: configuration)
        let actions = recognizer.process(
            joints: hand(pinchDistance: 0.08),
            timestamp: 1.1,
            configuration: configuration
        )

        #expect(actions == [.rightClick])
    }

    @Test
    func middlePinchCanBeMappedToLeftClick() {
        var recognizer = GestureRecognizer()
        var configuration = GestureConfiguration()
        configuration.middlePinchMapping = .leftClick
        _ = recognizer.process(
            joints: hand(middlePinchDistance: 0.01),
            timestamp: 1,
            configuration: configuration
        )
        let actions = recognizer.process(
            joints: hand(middlePinchDistance: 0.08),
            timestamp: 1.1,
            configuration: configuration
        )

        #expect(actions == [.click])
    }

    @Test
    func mappedDragStartsAfterDelayAndTrackingLossReleasesIt() {
        var recognizer = GestureRecognizer()
        var configuration = GestureConfiguration()
        configuration.middlePinchMapping = .drag
        configuration.dragStartDelay = 0.2
        _ = recognizer.process(
            joints: hand(middlePinchDistance: 0.01),
            timestamp: 1,
            configuration: configuration
        )
        let dragActions = recognizer.process(
            joints: hand(middlePinchDistance: 0.01),
            timestamp: 1.3,
            configuration: configuration
        )
        let lossActions = recognizer.process(joints: [], timestamp: 1.4, configuration: configuration)

        #expect(dragActions == [.beginDrag])
        #expect(lossActions == [.endDrag])
    }

    @Test
    func disabledPinchMappingDoesNotStartGesture() {
        var recognizer = GestureRecognizer()
        var configuration = GestureConfiguration()
        configuration.indexPinchMapping = .disabled
        let actions = recognizer.process(
            joints: hand(pinchDistance: 0.02),
            timestamp: 1,
            configuration: configuration
        )

        #expect(actions.contains(.move(normalizedX: 0.5, normalizedY: 0.6)))
        #expect(!recognizer.isPinching)
    }

    @Test
    func duplicatePinchActionsAreReportedUnlessDisabled() {
        #expect(PinchMappingConflict.hasDuplicateAction(index: .leftClick, middle: .leftClick))
        #expect(!PinchMappingConflict.hasDuplicateAction(index: .leftClick, middle: .rightClick))
        #expect(!PinchMappingConflict.hasDuplicateAction(index: .disabled, middle: .disabled))
    }

    @Test
    func scrollGestureReturnsToCursorWithoutMovingDuringScroll() {
        var recognizer = GestureRecognizer()
        _ = recognizer.process(joints: scrollHand(indexY: 0.6), timestamp: 1)
        _ = recognizer.process(joints: scrollHand(indexY: 0.52), timestamp: 1.1)
        _ = recognizer.process(joints: hand(pinchDistance: 0.08), timestamp: 1.2)
        let cursorActions = recognizer.process(joints: hand(pinchDistance: 0.08), timestamp: 1.3)

        #expect(cursorActions.contains { if case .move = $0 { true } else { false } })
        #expect(recognizer.activeGesture == .cursor)
    }

    private func hand(pinchDistance: Double) -> [HandJoint] {
        [
            HandJoint(name: "wrist", normalizedX: 0.5, normalizedY: 0.1, confidence: 1),
            HandJoint(name: "indexMCP", normalizedX: 0.5, normalizedY: 0.3, confidence: 1),
            HandJoint(name: "middleMCP", normalizedX: 0.7, normalizedY: 0.3, confidence: 1),
            HandJoint(name: "indexTip", normalizedX: 0.5, normalizedY: 0.6, confidence: 1),
            HandJoint(name: "middleTip", normalizedX: 0.7, normalizedY: 0.6, confidence: 1),
            HandJoint(name: "thumbTip", normalizedX: 0.5 + pinchDistance, normalizedY: 0.6, confidence: 1)
        ]
    }

    private func hand(middlePinchDistance: Double) -> [HandJoint] {
        [
            HandJoint(name: "wrist", normalizedX: 0.5, normalizedY: 0.1, confidence: 1),
            HandJoint(name: "indexMCP", normalizedX: 0.5, normalizedY: 0.3, confidence: 1),
            HandJoint(name: "middleMCP", normalizedX: 0.6, normalizedY: 0.3, confidence: 1),
            HandJoint(name: "indexTip", normalizedX: 0.5, normalizedY: 0.6, confidence: 1),
            HandJoint(name: "middleTip", normalizedX: 0.6, normalizedY: 0.6, confidence: 1),
            HandJoint(name: "thumbTip", normalizedX: 0.6 + middlePinchDistance, normalizedY: 0.6, confidence: 1)
        ]
    }

    private func scrollHand(indexY: Double) -> [HandJoint] {
        [
            HandJoint(name: "wrist", normalizedX: 0.5, normalizedY: 0.1, confidence: 1),
            HandJoint(name: "indexMCP", normalizedX: 0.5, normalizedY: 0.3, confidence: 1),
            HandJoint(name: "middleMCP", normalizedX: 0.58, normalizedY: 0.3, confidence: 1),
            HandJoint(name: "indexTip", normalizedX: 0.5, normalizedY: indexY, confidence: 1),
            HandJoint(name: "middleTip", normalizedX: 0.58, normalizedY: indexY, confidence: 1),
            HandJoint(name: "thumbTip", normalizedX: 0.35, normalizedY: 0.5, confidence: 1)
        ]
    }
}
