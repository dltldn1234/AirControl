import CoreVideo
import Vision

final class HandPoseDetector {
    private let request: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()

    func detect(in pixelBuffer: CVPixelBuffer) -> [[HandJoint]] {
        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            try handler.perform([request])
            return try (request.results ?? []).enumerated().map { handIndex, hand in
                try hand.recognizedPoints(.all).compactMap { name, point in
                    guard point.confidence >= 0.25 else { return nil }
                    return HandJoint(
                        name: String(describing: name),
                        normalizedX: point.location.x,
                        normalizedY: point.location.y,
                        confidence: Double(point.confidence),
                        handIndex: handIndex
                    )
                }
            }
        } catch {
            return []
        }
    }
}
