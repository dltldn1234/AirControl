import Testing
@testable import AirControl

struct AirControlTests {
    @Test
    func servicePlaceholdersCanBeConstructed() {
        _ = CameraManager()
        _ = HandPoseDetector()
        _ = GestureRecognizer()
        _ = CursorController()
    }
}
