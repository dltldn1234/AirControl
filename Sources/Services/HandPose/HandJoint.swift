import Foundation

struct HandJoint: Identifiable, Equatable, Sendable {
    let name: String
    let normalizedX: Double
    let normalizedY: Double
    let confidence: Double

    var id: String { name }
}
