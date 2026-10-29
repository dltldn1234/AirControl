import CoreGraphics
import Foundation

struct CursorCoordinateMapper {
    static func map(
        normalizedX: Double,
        normalizedY: Double,
        displayBounds: CGRect,
        activeArea: CGRect = CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84),
        mirrored: Bool = true,
        sensitivity: Double = 1
    ) -> CGPoint {
        let cameraX = mirrored ? 1 - normalizedX : normalizedX
        let areaWidth = max(activeArea.width, 0.001)
        let areaHeight = max(activeArea.height, 0.001)
        let calibratedX = min(max((cameraX - activeArea.minX) / areaWidth, 0), 1)
        let calibratedY = min(max((normalizedY - activeArea.minY) / areaHeight, 0), 1)
        let gain = min(max(sensitivity, 0.5), 2)
        let adjustedX = min(max((calibratedX - 0.5) * gain + 0.5, 0), 1)
        let adjustedY = min(max((calibratedY - 0.5) * gain + 0.5, 0), 1)
        return CGPoint(
            x: displayBounds.minX + adjustedX * displayBounds.width,
            y: displayBounds.minY + (1 - adjustedY) * displayBounds.height
        )
    }
}

struct CursorSmoother {
    private(set) var previousPoint: CGPoint?

    mutating func reset() {
        previousPoint = nil
    }

    mutating func apply(_ point: CGPoint, alpha: Double, deadZone: CGFloat) -> CGPoint {
        guard let previousPoint else {
            self.previousPoint = point
            return point
        }
        let deltaX = point.x - previousPoint.x
        let deltaY = point.y - previousPoint.y
        guard hypot(deltaX, deltaY) >= deadZone else { return previousPoint }
        let factor = min(max(alpha, 0.05), 1)
        let smoothed = CGPoint(
            x: previousPoint.x + deltaX * factor,
            y: previousPoint.y + deltaY * factor
        )
        self.previousPoint = smoothed
        return smoothed
    }
}
