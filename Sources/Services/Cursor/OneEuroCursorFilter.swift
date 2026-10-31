import CoreGraphics
import Foundation

struct CursorFilterConfiguration {
    var minimumCutoff = 1.2
    var beta = 0.004
    var derivativeCutoff = 1.0
    var deadZone: CGFloat = 1.5
    var maximumSpeed: CGFloat = 5_000
    var maximumJump: CGFloat = 700
}

struct OneEuroCursorFilter {
    private(set) var previousRawPoint: CGPoint?
    private(set) var previousFilteredPoint: CGPoint?
    private var previousFilteredDerivative = CGPoint.zero
    private var previousTimestamp: TimeInterval?

    mutating func reset() {
        previousRawPoint = nil
        previousFilteredPoint = nil
        previousFilteredDerivative = .zero
        previousTimestamp = nil
    }

    mutating func apply(
        _ point: CGPoint,
        timestamp: TimeInterval,
        configuration: CursorFilterConfiguration = CursorFilterConfiguration()
    ) -> CGPoint {
        guard let previousRawPoint, let previousFilteredPoint, let previousTimestamp else {
            self.previousRawPoint = point
            previousFilteredPoint = point
            previousTimestamp = timestamp
            return point
        }

        let deltaTime = min(max(timestamp - previousTimestamp, 1.0 / 240), 0.1)
        let deltaTimePoints = CGFloat(deltaTime)
        let boundedPoint = limitJump(from: previousRawPoint, to: point, maximumDistance: configuration.maximumJump)
        let rawDerivative = CGPoint(
            x: (boundedPoint.x - previousRawPoint.x) / deltaTimePoints,
            y: (boundedPoint.y - previousRawPoint.y) / deltaTimePoints
        )
        let derivativeAlpha = Self.alpha(cutoff: configuration.derivativeCutoff, deltaTime: deltaTime)
        let filteredDerivative = lowPass(rawDerivative, previous: previousFilteredDerivative, alpha: derivativeAlpha)
        let cutoff = max(configuration.minimumCutoff, 0.01)
            + max(configuration.beta, 0) * hypot(filteredDerivative.x, filteredDerivative.y)
        let valueAlpha = Self.alpha(cutoff: cutoff, deltaTime: deltaTime)
        let filteredPoint = lowPass(boundedPoint, previous: previousFilteredPoint, alpha: valueAlpha)
        let deadZonePoint = distance(filteredPoint, previousFilteredPoint) < configuration.deadZone
            ? previousFilteredPoint
            : filteredPoint
        let maximumStep = max(configuration.maximumSpeed, 1) * deltaTimePoints
        let output = limitJump(from: previousFilteredPoint, to: deadZonePoint, maximumDistance: maximumStep)

        self.previousRawPoint = boundedPoint
        self.previousFilteredPoint = output
        previousFilteredDerivative = filteredDerivative
        self.previousTimestamp = timestamp
        return output
    }

    private func lowPass(_ point: CGPoint, previous: CGPoint, alpha: Double) -> CGPoint {
        CGPoint(
            x: previous.x + CGFloat(alpha) * (point.x - previous.x),
            y: previous.y + CGFloat(alpha) * (point.y - previous.y)
        )
    }

    private func limitJump(from start: CGPoint, to end: CGPoint, maximumDistance: CGFloat) -> CGPoint {
        let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let distance = hypot(delta.x, delta.y)
        guard distance > maximumDistance, distance > 0 else { return end }
        let ratio = maximumDistance / distance
        return CGPoint(x: start.x + delta.x * ratio, y: start.y + delta.y * ratio)
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private static func alpha(cutoff: Double, deltaTime: Double) -> Double {
        let safeCutoff = max(cutoff, 0.01)
        let tau = 1 / (2 * Double.pi * safeCutoff)
        return 1 / (1 + tau / deltaTime)
    }
}
