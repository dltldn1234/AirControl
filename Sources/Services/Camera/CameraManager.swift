import AVFoundation
import CoreMedia
import Darwin
import Foundation

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
            "No built-in or default camera is available."
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

final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let captureSession = AVCaptureSession()
    var onFrame: (([[HandJoint]], Double) -> Void)?
    var onPerformance: ((Double, Double) -> Void)?

    private let sessionQueue = DispatchQueue(label: "aircontrol.camera.session")
    private let frameQueue = DispatchQueue(label: "aircontrol.camera.frames", qos: .userInteractive)
    private let handPoseDetector = HandPoseDetector()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var lastFrameTime: CFTimeInterval?
    private var previousCPUTime: Double?
    private var previousCPUWallTime: CFTimeInterval?

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
                DispatchQueue.main.async { [weak self] in
                    self?.onFrame?([], 0)
                }
                continuation.resume()
            }
        }
    }

    private func configureSessionIfNeeded() throws {
        guard captureSession.inputs.isEmpty, captureSession.outputs.isEmpty else { return }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video) else {
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
