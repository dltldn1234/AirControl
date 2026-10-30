import Foundation

struct HandJoint: Identifiable, Equatable, Sendable {
    let name: String
    let normalizedX: Double
    let normalizedY: Double
    let confidence: Double
    let handIndex: Int

    init(name: String, normalizedX: Double, normalizedY: Double, confidence: Double, handIndex: Int = 0) {
        self.name = name
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.confidence = confidence
        self.handIndex = handIndex
    }

    var id: String { handIndex == 0 ? name : "\(handIndex)-\(name)" }
}
