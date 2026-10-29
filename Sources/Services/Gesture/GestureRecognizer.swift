import Foundation

enum GestureAction: Equatable {
    case move(normalizedX: Double, normalizedY: Double)
    case click
    case beginDrag
    case endDrag
}

struct GestureConfiguration {
    var pinchStartThreshold = 0.32
    var pinchReleaseThreshold = 0.48
    var dragStartDelay: TimeInterval = 0.45
}

struct GestureRecognizer {
    private(set) var isPinching = false
    private(set) var isDragging = false
    private var pinchStartedAt: TimeInterval?
    private var lastClickAt: TimeInterval = -.infinity

    mutating func process(
        joints: [HandJoint],
        timestamp: TimeInterval,
        configuration: GestureConfiguration = GestureConfiguration()
    ) -> [GestureAction] {
        guard let indexTip = joints.first(where: { $0.name.contains("indexTip") }) else {
            return resetForTrackingLoss()
        }
        guard let thumbTip = joints.first(where: { $0.name.contains("thumbTip") }),
              let wrist = joints.first(where: { $0.name.contains("wrist") }),
              let indexMCP = joints.first(where: { $0.name.contains("indexMCP") }) else {
            let movement = GestureAction.move(
                normalizedX: indexTip.normalizedX,
                normalizedY: indexTip.normalizedY
            )
            return [movement] + resetForTrackingLoss()
        }

        let palmScale = max(
            hypot(indexMCP.normalizedX - wrist.normalizedX, indexMCP.normalizedY - wrist.normalizedY),
            0.001
        )
        let pinchDistance = hypot(
            thumbTip.normalizedX - indexTip.normalizedX,
            thumbTip.normalizedY - indexTip.normalizedY
        ) / palmScale
        var actions: [GestureAction] = [.move(normalizedX: indexTip.normalizedX, normalizedY: indexTip.normalizedY)]

        if isPinching {
            if pinchDistance >= configuration.pinchReleaseThreshold {
                if isDragging {
                    actions.append(.endDrag)
                } else if let pinchStartedAt,
                          timestamp - pinchStartedAt < configuration.dragStartDelay,
                          timestamp - lastClickAt >= 0.25 {
                    actions.append(.click)
                    lastClickAt = timestamp
                }
                isPinching = false
                isDragging = false
                pinchStartedAt = nil
            } else if !isDragging,
                      let pinchStartedAt,
                      timestamp - pinchStartedAt >= configuration.dragStartDelay {
                isDragging = true
                actions.append(.beginDrag)
            }
        } else if pinchDistance <= configuration.pinchStartThreshold {
            isPinching = true
            pinchStartedAt = timestamp
        }
        return actions
    }

    mutating func resetForTrackingLoss() -> [GestureAction] {
        let actions: [GestureAction] = isDragging ? [.endDrag] : []
        isPinching = false
        isDragging = false
        pinchStartedAt = nil
        return actions
    }
}
