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

enum PinchActionMapping: String, CaseIterable, Identifiable {
    case leftClick
    case rightClick
    case drag
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftClick: "Left click"
        case .rightClick: "Right click"
        case .drag: "Drag"
        case .disabled: "Disabled"
        }
    }
}

enum PinchMappingConflict {
    static func hasDuplicateAction(index: PinchActionMapping, middle: PinchActionMapping) -> Bool {
        index != .disabled && index == middle
    }
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
    var indexPinchMapping = PinchActionMapping.leftClick
    var middlePinchMapping = PinchActionMapping.rightClick
}

private struct HandGesturePose {
    private static let cursorTipConfidenceThreshold = 0.55

    let indexTip: CGPoint
    let indexPinch: Double
    let middlePinch: Double
    let scrollPose: Bool

    init?(joints: [HandJoint]) {
        // Cursor position always comes from the index fingertip. A low-confidence
        // fingertip is treated as tracking loss so the cursor cannot jump to a
        // palm or wrist fallback.
        guard let indexTip = Self.point(
            "indexTip",
            in: joints,
            minimumConfidence: Self.cursorTipConfidenceThreshold
        ),
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

    private static func point(
        _ name: String,
        in joints: [HandJoint],
        minimumConfidence: Double = 0.25
    ) -> CGPoint? {
        guard let joint = joints.first(where: {
            $0.name.contains(name) && $0.confidence >= minimumConfidence
        }) else { return nil }
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
    private var activePinchMapping = PinchActionMapping.disabled
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
        if let source = pinchSource(pose, configuration: configuration) {
            isPinching = true
            pinchStartedAt = timestamp
            pinchType = source
            activePinchMapping = mapping(for: pinchType, configuration: configuration)
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
        activePinchMapping = .disabled
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
            guard pinchDistance(pose) >= configuration.pinchReleaseThreshold else { return [] }
            isDragging = false
            isPinching = false
            pinchStartedAt = nil
            activePinchMapping = .disabled
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
        let actionMapping = activePinchMapping
        let pinchRemainsActive = pinchType == .click
            ? pose.indexPinch <= configuration.pinchStartThreshold
            : pose.middlePinch <= configuration.pinchStartThreshold
        if pinchRemainsActive {
            let startsDrag = actionMapping == .drag || (pinchType == .click && actionMapping == .leftClick)
            if startsDrag, configuration.dragEnabled,
               timestamp - (pinchStartedAt ?? timestamp) >= configuration.dragStartDelay {
                isDragging = true
                activeGesture = .drag
                return [.beginDrag]
            }
            activeGesture = pinchType
            return []
        }

        isPinching = false
        pinchStartedAt = nil
        activePinchMapping = .disabled
        activeGesture = .cursor
        guard pinchDistance(pose) <= configuration.pinchReleaseThreshold else { return [] }
        switch actionMapping {
        case .leftClick where configuration.leftClickEnabled && timestamp - lastClickAt >= 0.25:
            lastClickAt = timestamp
            return [.click]
        case .rightClick where configuration.rightClickEnabled && timestamp - lastRightClickAt >= 0.35:
            lastRightClickAt = timestamp
            return [.rightClick]
        case .leftClick, .rightClick, .drag, .disabled:
            break
        }
        return []
    }

    private func pinchSource(_ pose: HandGesturePose, configuration: GestureConfiguration) -> ActiveGesture? {
        let indexPinchIsActive = configuration.indexPinchMapping != .disabled
            && pose.indexPinch <= configuration.pinchStartThreshold
        let middlePinchIsActive = configuration.rightClickGestureEnabled
            && configuration.middlePinchMapping != .disabled
            && pose.middlePinch <= configuration.pinchStartThreshold
        guard indexPinchIsActive || middlePinchIsActive else { return nil }
        guard indexPinchIsActive, middlePinchIsActive else {
            return indexPinchIsActive ? .click : .rightClick
        }
        return pose.indexPinch <= pose.middlePinch ? .click : .rightClick
    }

    private func mapping(for gesture: ActiveGesture, configuration: GestureConfiguration) -> PinchActionMapping {
        gesture == .click ? configuration.indexPinchMapping : configuration.middlePinchMapping
    }

    private func pinchDistance(_ pose: HandGesturePose) -> Double {
        pinchType == .click ? pose.indexPinch : pose.middlePinch
    }

    private mutating func clearScrollState() {
        previousScrollY = nil
        scrollOriginY = nil
        scrollCandidateY = nil
    }
}
