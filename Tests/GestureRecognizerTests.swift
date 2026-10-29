import Testing
@testable import AirControl

struct GestureRecognizerTests {
    @Test
    func shortPinchCreatesOneClickAfterRelease() {
        var recognizer = GestureRecognizer()
        _ = recognizer.process(joints: hand(pinchDistance: 0.02), timestamp: 1)
        let actions = recognizer.process(joints: hand(pinchDistance: 0.12), timestamp: 1.1)

        #expect(actions.contains(.click))
        #expect(!recognizer.isPinching)
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
        let firstRelease = recognizer.process(joints: hand(pinchDistance: 0.12), timestamp: 1.1)
        _ = recognizer.process(joints: hand(pinchDistance: 0.02), timestamp: 1.2)
        let secondRelease = recognizer.process(joints: hand(pinchDistance: 0.12), timestamp: 1.3)

        #expect(firstRelease.contains(.click))
        #expect(!secondRelease.contains(.click))
    }

    private func hand(pinchDistance: Double) -> [HandJoint] {
        [
            HandJoint(name: "wrist", normalizedX: 0.5, normalizedY: 0.1, confidence: 1),
            HandJoint(name: "indexMCP", normalizedX: 0.5, normalizedY: 0.3, confidence: 1),
            HandJoint(name: "indexTip", normalizedX: 0.5, normalizedY: 0.6, confidence: 1),
            HandJoint(name: "thumbTip", normalizedX: 0.5 + pinchDistance, normalizedY: 0.6, confidence: 1)
        ]
    }
}
