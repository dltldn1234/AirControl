import Foundation

enum GestureAction: Equatable {
    case move(normalizedX: Double, normalizedY: Double)
    case click
    case rightClick
    case beginDrag
    case endDrag
    case scroll(delta: Double)
}

enum ActiveGesture: String, Equatable {
    case cursor = "Cursor"
    case click = "Click"
    case drag = "Drag"
    case scroll = "Scroll"
    case rightClick = "Right Click"
    case trackingLost = "Hand not detected"
}

struct GestureConfiguration {
    var pinchStartThreshold = 0.32
    var pinchReleaseThreshold = 0.48
    var dragStartDelay: TimeInterval = 0.45
    var scrollStartThreshold = 0.055
    var scrollDeadZone = 0.008
    var scrollSensitivity = 1.0
    var reversesScrollDirection = false
    var rightClickEnabled = true
    var rightClickGestureEnabled = true
    var cursorEnabled = true
    var leftClickEnabled = true
    var dragEnabled = true
    var scrollEnabled = true
    var scrollGestureEnabled = true
}

private struct HandGesturePose {
    let indexTip: CGPoint
    let indexPinch: Double
    let middlePinch: Double
    let scrollPose: Bool

    init?(joints: [HandJoint]) {
        guard let indexTip = Self.point("indexTip", in: joints),
              let wrist = Self.point("wrist", in: joints),
              let indexMCP = Self.point("indexMCP", in: joints),
              let thumbTip = Self.point("thumbTip", in: joints) else { return nil }
        self.indexTip = indexTip
        let palmScale = max(Self.distance(indexMCP, wrist), 0.001)
        indexPinch = Self.distance(thumbTip, indexTip) / palmScale
        if let middleTip = Self.point("middleTip", in: joints),
           let middleMCP = Self.point("middleMCP", in: joints) {
            let middleScale = max(Self.distance(middleMCP, wrist), 0.001)
            middlePinch = Self.distance(thumbTip, middleTip) / middleScale
            scrollPose = Self.distance(indexTip, indexMCP) > palmScale * 0.75
                && Self.distance(middleTip, middleMCP) > middleScale * 0.75
                && indexPinch > 0.48 && middlePinch > 0.48
        } else {
            middlePinch = .greatestFiniteMagnitude
            scrollPose = false
        }
    }

    private static func point(_ name: String, in joints: [HandJoint]) -> CGPoint? {
        guard let joint = joints.first(where: { $0.name.contains(name) }) else { return nil }
        return CGPoint(x: joint.normalizedX, y: joint.normalizedY)
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}

struct GestureRecognizer {
    private(set) var isPinching = false
    private(set) var isDragging = false
    private(set) var activeGesture: ActiveGesture = .trackingLost
    private var pinchStartedAt: TimeInterval?
    private var pinchType: ActiveGesture = .click
    private var lastClickAt: TimeInterval = -.infinity
    private var lastRightClickAt: TimeInterval = -.infinity
    private var previousScrollY: Double?
    private var scrollOriginY: Double?
    private var scrollCandidateY: Double?

    mutating func process(
        joints: [HandJoint],
        timestamp: TimeInterval,
        configuration: GestureConfiguration = GestureConfiguration()
    ) -> [GestureAction] {
        guard let pose = HandGesturePose(joints: joints) else { return resetForTrackingLoss() }
        guard configuration.cursorEnabled || configuration.leftClickEnabled || configuration.rightClickEnabled
            || configuration.scrollEnabled else { return resetForTrackingLoss() }
        if activeGesture == .scroll { return processScroll(pose, configuration: configuration) }
        if isPinching { return processPinch(pose, timestamp: timestamp, configuration: configuration) }
        if pose.scrollPose, configuration.scrollEnabled, configuration.scrollGestureEnabled {
            guard let scrollCandidateY else {
                self.scrollCandidateY = pose.indexTip.y
                return []
            }
            guard abs(pose.indexTip.y - scrollCandidateY) > 0.025 else { return [] }
            self.scrollOriginY = scrollCandidateY
            previousScrollY = scrollCandidateY
            self.scrollCandidateY = nil
            activeGesture = .scroll
            return processScroll(pose, configuration: configuration)
        }
        scrollCandidateY = nil
        if shouldStartPinch(pose, configuration: configuration) {
            isPinching = true
            pinchStartedAt = timestamp
            pinchType = pose.indexPinch <= pose.middlePinch ? .click : .rightClick
            activeGesture = pinchType
            return []
        }
        activeGesture = .cursor
        clearScrollState()
        return configuration.cursorEnabled ? [.move(normalizedX: pose.indexTip.x, normalizedY: pose.indexTip.y)] : []
    }

    mutating func resetForTrackingLoss() -> [GestureAction] {
        let actions: [GestureAction] = isDragging ? [.endDrag] : []
        isPinching = false
        isDragging = false
        activeGesture = .trackingLost
        pinchStartedAt = nil
        clearScrollState()
        return actions
    }

    private mutating func processScroll(
        _ pose: HandGesturePose,
        configuration: GestureConfiguration
    ) -> [GestureAction] {
        guard pose.scrollPose else {
            activeGesture = .cursor
            clearScrollState()
            return []
        }
        defer { previousScrollY = pose.indexTip.y }
        guard let previousScrollY else { return [] }
        let movement = pose.indexTip.y - previousScrollY
        guard abs(movement) >= configuration.scrollDeadZone,
              abs(pose.indexTip.y - (scrollOriginY ?? pose.indexTip.y)) >= configuration.scrollStartThreshold else {
            return []
        }
        let direction = configuration.reversesScrollDirection ? -1.0 : 1.0
        return [.scroll(delta: movement * configuration.scrollSensitivity * direction)]
    }

    private mutating func processPinch(
        _ pose: HandGesturePose,
        timestamp: TimeInterval,
        configuration: GestureConfiguration
    ) -> [GestureAction] {
        if isDragging {
            guard pose.indexPinch >= configuration.pinchReleaseThreshold else { return [] }
            isDragging = false
            isPinching = false
            pinchStartedAt = nil
            activeGesture = .cursor
            return [.endDrag]
        }
        return processClickOrRightClick(pose, timestamp: timestamp, configuration: configuration)
    }

    private mutating func processClickOrRightClick(
        _ pose: HandGesturePose,
        timestamp: TimeInterval,
        configuration: GestureConfiguration
    ) -> [GestureAction] {
        if pose.indexPinch <= configuration.pinchStartThreshold {
            pinchType = .click
            activeGesture = .click
            if configuration.dragEnabled,
               timestamp - (pinchStartedAt ?? timestamp) >= configuration.dragStartDelay {
                isDragging = true
                activeGesture = .drag
                return [.beginDrag]
            }
            return []
        }
        if configuration.rightClickEnabled, configuration.rightClickGestureEnabled,
           pose.middlePinch <= configuration.pinchStartThreshold {
            let isRightClick = pose.middlePinch < pose.indexPinch
            pinchType = isRightClick ? .rightClick : .click
            activeGesture = pinchType
            return []
        }

        isPinching = false
        pinchStartedAt = nil
        activeGesture = .cursor
        if pinchType == .click, pose.indexPinch <= configuration.pinchReleaseThreshold,
           timestamp - lastClickAt >= 0.25, configuration.leftClickEnabled {
            lastClickAt = timestamp
            return [.click]
        }
        if pinchType == .rightClick, pose.middlePinch <= configuration.pinchReleaseThreshold,
           timestamp - lastRightClickAt >= 0.35, configuration.rightClickEnabled,
           configuration.rightClickGestureEnabled {
            lastRightClickAt = timestamp
            return [.rightClick]
        }
        return []
    }

    private func shouldStartPinch(_ pose: HandGesturePose, configuration: GestureConfiguration) -> Bool {
        pose.indexPinch <= configuration.pinchStartThreshold
            || (configuration.rightClickEnabled && configuration.rightClickGestureEnabled
                && pose.middlePinch <= configuration.pinchStartThreshold)
    }

    private mutating func clearScrollState() {
        previousScrollY = nil
        scrollOriginY = nil
        scrollCandidateY = nil
    }
}
