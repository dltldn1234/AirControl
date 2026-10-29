import CoreVideo
import Vision

final class HandPoseDetector {
    private let request: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()

    func detect(in pixelBuffer: CVPixelBuffer) -> [HandJoint] {
        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            try handler.perform([request])
            guard let hand = request.results?.first else { return [] }
            return try hand.recognizedPoints(.all).compactMap { name, point in
                guard point.confidence >= 0.25 else { return nil }
                return HandJoint(
                    name: String(describing: name),
                    normalizedX: point.location.x,
                    normalizedY: point.location.y,
                    confidence: Double(point.confidence)
                )
            }
        } catch {
            return []
        }
    }
}
