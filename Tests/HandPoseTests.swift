import Testing
@testable import AirControl

struct HandPoseTests {
    @Test
    func handJointPreservesNormalizedCoordinatesAndConfidence() {
        let joint = HandJoint(name: "indexTip", normalizedX: 0.25, normalizedY: 0.75, confidence: 0.9)

        #expect(joint.id == "indexTip")
        #expect(joint.normalizedX == 0.25)
        #expect(joint.normalizedY == 0.75)
        #expect(joint.confidence == 0.9)
    }
}
