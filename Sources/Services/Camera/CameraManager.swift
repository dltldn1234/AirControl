import AVFoundation
import CoreMedia
import Darwin
import Foundation

struct CameraDeviceChoice: Identifiable, Hashable {
    let id: String
    let name: String
    let isBuiltIn: Bool
}

enum CameraDeviceSelection {
    static func resolve(preferredID: String?, availableIDs: [String], frontCameraID: String?) -> String? {
        if let preferredID, availableIDs.contains(preferredID) {
            return preferredID
        }
        if let frontCameraID, availableIDs.contains(frontCameraID) {
            return frontCameraID
        }
        return availableIDs.first
    }
}

enum CameraManagerError: LocalizedError {
    case permissionDenied
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Camera access is denied. Allow it in System Settings → Privacy & Security → Camera."
        case .cameraUnavailable:
            "No supported video camera is available."
        case .cannotAddInput:
            "The camera input could not be added to the capture session."
        case .cannotAddOutput:
            "The video output could not be added to the capture session."
        }
    }
}

enum CameraFrameMetrics {
    static func framesPerSecond(previousFrameTime: CFTimeInterval?, currentFrameTime: CFTimeInterval) -> Double {
        guard let previousFrameTime else { return 0 }
        let elapsed = currentFrameTime - previousFrameTime
        guard elapsed.isFinite, elapsed > 0 else { return 0 }
        return 1 / elapsed
    }

    static func cpuPercent(cpuTimeDelta: Double, wallTimeDelta: CFTimeInterval) -> Double? {
        guard cpuTimeDelta.isFinite, wallTimeDelta.isFinite, cpuTimeDelta >= 0, wallTimeDelta > 0 else {
            return nil
        }
        return min(max(cpuTimeDelta / wallTimeDelta * 100, 0), 100)
    }
}

enum CameraPermissionGate {
    static func allowsCapture(for authorizationStatus: AVAuthorizationStatus) -> Bool {
        authorizationStatus == .authorized
    }
}

enum CameraManagerStatus: Equatable {
    case interrupted(String)
    case resumed
    case failed(String)

    static let interruptionMessage = "Camera capture was interrupted by macOS."
}

final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let captureSession = AVCaptureSession()
    var onFrame: (([[HandJoint]], Double) -> Void)?
    var onPerformance: ((Double, Double) -> Void)?
    var onStatus: ((CameraManagerStatus) -> Void)?

    private let sessionQueue = DispatchQueue(label: "aircontrol.camera.session")
    private let frameQueue = DispatchQueue(label: "aircontrol.camera.frames", qos: .userInteractive)
    private let handPoseDetector = HandPoseDetector()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var lastFrameTime: CFTimeInterval?
    private var previousCPUTime: Double?
    private var previousCPUWallTime: CFTimeInterval?
    private var notificationObservers: [NSObjectProtocol] = []

    override init() {
        super.init()
        observeSessionNotifications()
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
    }

    static func availableCameras() -> [CameraDeviceChoice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.map { camera in
            CameraDeviceChoice(
                id: camera.uniqueID,
                name: camera.localizedName,
                isBuiltIn: camera.deviceType == .builtInWideAngleCamera
            )
        }
    }

    func start() async throws {
        var authorization = AVCaptureDevice.authorizationStatus(for: .video)
        if authorization == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorization = granted ? .authorized : .denied
        }
        guard CameraPermissionGate.allowsCapture(for: authorization) else {
            throw CameraManagerError.permissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraManagerError.cameraUnavailable)
                    return
                }
                do {
                    try configureSessionIfNeeded()
                    if !captureSession.isRunning {
                        captureSession.startRunning()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                tearDownSession()
                deliverEmptyFrame()
                continuation.resume()
            }
        }
    }

    private func observeSessionNotifications() {
        let center = NotificationCenter.default
        notificationObservers.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: captureSession,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            sessionQueue.async { [weak self] in
                self?.deliverEmptyFrame()
                self?.deliverStatus(.interrupted(CameraManagerStatus.interruptionMessage))
            }
        })
        notificationObservers.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: captureSession,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            sessionQueue.async { [weak self] in self?.deliverStatus(.resumed) }
        })
        notificationObservers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: captureSession,
            queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            sessionQueue.async { [weak self] in
                guard let self else { return }
                let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
                self.tearDownSession()
                self.deliverEmptyFrame()
                self.deliverStatus(.failed(error?.localizedDescription ?? "Camera encountered a runtime error."))
            }
        })
    }

    private func tearDownSession() {
        captureSession.stopRunning()
        videoOutput?.setSampleBufferDelegate(nil, queue: nil)
        frameQueue.sync {}
        captureSession.beginConfiguration()
        captureSession.inputs.forEach(captureSession.removeInput)
        captureSession.outputs.forEach(captureSession.removeOutput)
        captureSession.commitConfiguration()
        videoOutput = nil
        lastFrameTime = nil
        previousCPUTime = nil
        previousCPUWallTime = nil
        currentCPUPercent = 0
    }

    private func deliverEmptyFrame() {
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?([], 0)
        }
    }

    private func deliverStatus(_ status: CameraManagerStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.onStatus?(status)
        }
    }

    private func configureSessionIfNeeded() throws {
        guard captureSession.inputs.isEmpty, captureSession.outputs.isEmpty else { return }
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
        let availableIDs = devices.map(\.uniqueID)
        let preferredID = UserDefaults.standard.string(forKey: "selectedCameraUniqueID")
        let frontCameraID = devices.first(where: {
            $0.deviceType == .builtInWideAngleCamera && $0.position == .front
        })?.uniqueID
        guard let selectedID = CameraDeviceSelection.resolve(
            preferredID: preferredID,
            availableIDs: availableIDs,
            frontCameraID: frontCameraID
        ), let camera = devices.first(where: { $0.uniqueID == selectedID }) else {
            throw CameraManagerError.cameraUnavailable
        }
        let input = try AVCaptureDeviceInput(device: camera)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: frameQueue)

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        guard captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            throw CameraManagerError.cannotAddInput
        }
        captureSession.addInput(input)
        guard captureSession.canAddOutput(output) else {
            captureSession.removeInput(input)
            captureSession.commitConfiguration()
            throw CameraManagerError.cannotAddOutput
        }
        captureSession.addOutput(output)
        captureSession.commitConfiguration()
        videoOutput = output
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let currentTime = CACurrentMediaTime()
        let hands = handPoseDetector.detect(in: pixelBuffer)
        let finishedTime = CACurrentMediaTime()
        let fps = CameraFrameMetrics.framesPerSecond(previousFrameTime: lastFrameTime, currentFrameTime: finishedTime)
        let inferenceMilliseconds = (finishedTime - currentTime) * 1_000
        lastFrameTime = finishedTime
        measureCPU(at: finishedTime)
        let cpu = currentCPUPercent
        onFrame?(hands, fps)
        onPerformance?(inferenceMilliseconds, cpu)
    }

    private var currentCPUPercent = 0.0

    private func measureCPU(at wallTime: CFTimeInterval) {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return }
        let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
        let system = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        let cpuTime = user + system
        if let previousCPUTime, let previousCPUWallTime, wallTime > previousCPUWallTime {
            currentCPUPercent = CameraFrameMetrics.cpuPercent(
                cpuTimeDelta: cpuTime - previousCPUTime,
                wallTimeDelta: wallTime - previousCPUWallTime
            ) ?? currentCPUPercent
        }
        previousCPUTime = cpuTime
        previousCPUWallTime = wallTime
    }
}
