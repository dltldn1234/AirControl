import Combine
import Foundation

@MainActor
final class CameraTrackingViewModel: ObservableObject {
    @Published private(set) var status = "Camera stopped"
    @Published private(set) var isStarting = false
    @Published private(set) var isRunning = false
    @Published private(set) var joints: [HandJoint] = []
    @Published private(set) var framesPerSecond = 0.0

    let cameraManager = CameraManager()

    init() {
        cameraManager.onFrame = { [weak self] joints, fps in
            Task { @MainActor in
                self?.joints = joints
                self?.framesPerSecond = fps
                self?.status = joints.isEmpty ? "No hand detected" : "Hand detected"
            }
        }
    }

    func startCamera() {
        guard !isStarting, !isRunning else { return }
        isStarting = true
        status = "Requesting camera access…"
        Task {
            do {
                try await cameraManager.start()
                isRunning = true
                status = "Looking for a hand…"
            } catch {
                status = error.localizedDescription
            }
            isStarting = false
        }
    }

    func stopCamera() {
        guard isRunning || isStarting else { return }
        isStarting = false
        isRunning = false
        status = "Stopping camera…"
        Task {
            await cameraManager.stop()
            joints = []
            framesPerSecond = 0
            status = "Camera stopped"
        }
    }
}
