import CoreGraphics
import Foundation

enum WindowGestureMode: String, Equatable {
    case idle = "Idle"
    case cursorControl = "CursorControl"
    case windowControl = "WindowControl"
    case windowMoving = "WindowMoving"
    case windowResizing = "WindowResizing"
    case appSwitching = "AppSwitching"
}

enum WindowGestureAction: Equatable {
    case enterWindowControl
    case exitWindowControl
    case beginMoving(anchor: CGPoint)
    case moveWindow(position: CGPoint, sensitivity: Double)
    case endMoving
    case beginResizing
    case resizeWindow(scale: Double, smoothing: Double)
    case endResizing
    case switchApp(direction: Int)
}

struct WindowGestureConfiguration {
    var enabled = false
    var windowControlEnabled = false
    var appSwitchEnabled = false
    var twoHandResizeEnabled = false
    var moveSensitivity = 1.0
    var resizeSmoothing = 0.25
    var palmHoldDuration: TimeInterval = 0.7
    var fistHoldDuration: TimeInterval = 0.9
    var appSwitchCooldown: TimeInterval = 0.8
}

struct WindowGestureResult {
    let actions: [WindowGestureAction]
    let suppressCursor: Bool
    let mode: WindowGestureMode
}

struct TwoHandResizeTracker {
    private(set) var baselineDistance: Double?
    private var previousPoints: (CGPoint, CGPoint)?
    private var reverseObservationOrder = false

    mutating func begin(_ points: [CGPoint]) -> Double? {
        guard points.count == 2 else { return nil }
        reverseObservationOrder = points[0].x > points[1].x
        let ordered = logicalPoints(points)
        let distance = WindowGeometry.interHandDistance(ordered[0], ordered[1])
        guard distance > 0.04 else { return nil }
        baselineDistance = distance
        previousPoints = (ordered[0], ordered[1])
        return distance
    }

    mutating func scale(for points: [CGPoint]) -> Double? {
        guard points.count == 2, let baselineDistance, let previousPoints else { return nil }
        let ordered = logicalPoints(points)
        guard ordered[0].x < ordered[1].x else { return nil }
        let directDistance = WindowGeometry.interHandDistance(ordered[0], previousPoints.0)
            + WindowGeometry.interHandDistance(ordered[1], previousPoints.1)
        let crossedDistance = WindowGeometry.interHandDistance(ordered[1], previousPoints.0)
            + WindowGeometry.interHandDistance(ordered[0], previousPoints.1)
        guard crossedDistance >= directDistance else { return nil }
        let distance = WindowGeometry.interHandDistance(ordered[0], ordered[1])
        guard distance > 0.04 else { return nil }
        self.previousPoints = (ordered[0], ordered[1])
        return min(max(distance / baselineDistance, 0.5), 2.0)
    }

    mutating func reset() {
        baselineDistance = nil
        previousPoints = nil
        reverseObservationOrder = false
    }

    private func logicalPoints(_ points: [CGPoint]) -> [CGPoint] {
        reverseObservationOrder ? [points[1], points[0]] : points
    }
}

struct WindowGestureRecognizer {
    private(set) var mode: WindowGestureMode = .idle
    private var palmStartedAt: TimeInterval?
    private var fistStartedAt: TimeInterval?
    private var pinchStarted = false
    private var appSwipeStart: (x: Double, time: TimeInterval)?
    private var lastAppSwitchAt = -Double.infinity
    private var resizeTracker = TwoHandResizeTracker()

    mutating func process(
        hands: [[HandJoint]],
        timestamp: TimeInterval,
        configuration: WindowGestureConfiguration
    ) -> WindowGestureResult {
        guard configuration.enabled else {
            let actions = reset()
            return WindowGestureResult(actions: actions, suppressCursor: false, mode: .idle)
        }
        if !configuration.windowControlEnabled,
           mode == .windowControl || mode == .windowMoving || mode == .windowResizing {
            let actions = resetActiveGesture()
            return WindowGestureResult(actions: actions, suppressCursor: true, mode: .idle)
        }
        guard !hands.isEmpty else {
            let actions = resetActiveGesture()
            return WindowGestureResult(actions: actions, suppressCursor: false, mode: .idle)
        }

        if mode == .windowResizing {
            return processResize(hands: hands, configuration: configuration)
        }
        if mode == .windowMoving {
            return processMove(hands.first ?? [], configuration: configuration)
        }
        if mode == .windowControl {
            return processWindowControl(hands: hands, timestamp: timestamp, configuration: configuration)
        }
        return processIdle(hands: hands, timestamp: timestamp, configuration: configuration)
    }

    mutating func reset() -> [WindowGestureAction] {
        let actions = resetActiveGesture()
        mode = .idle
        palmStartedAt = nil
        fistStartedAt = nil
        appSwipeStart = nil
        pinchStarted = false
        return actions
    }

    private mutating func processIdle(
        hands: [[HandJoint]],
        timestamp: TimeInterval,
        configuration: WindowGestureConfiguration
    ) -> WindowGestureResult {
        guard let hand = hands.first else { return result([], suppress: false) }
        if configuration.windowControlEnabled, isOpenPalm(hand) {
            appSwipeStart = nil
            let start = palmStartedAt ?? timestamp
            palmStartedAt = start
            guard timestamp - start >= configuration.palmHoldDuration else {
                return result([], suppress: true)
            }
            mode = .windowControl
            palmStartedAt = nil
            return result([.enterWindowControl], suppress: true)
        }
        palmStartedAt = nil
        if configuration.appSwitchEnabled, !isOpenPalm(hand), isThreeFingerPose(hand) {
            return processAppSwipe(hand, timestamp: timestamp, cooldown: configuration.appSwitchCooldown)
        }
        appSwipeStart = nil
        return result([], suppress: false, mode: .cursorControl)
    }

    private mutating func processWindowControl(
        hands: [[HandJoint]],
        timestamp: TimeInterval,
        configuration: WindowGestureConfiguration
    ) -> WindowGestureResult {
        guard let hand = hands.first else { return exitWindowControl() }
        let wristPoints = hands.prefix(2).compactMap(wristPoint)
        if isFist(hand) {
            let start = fistStartedAt ?? timestamp
            fistStartedAt = start
            guard timestamp - start >= configuration.fistHoldDuration else { return result([], suppress: true) }
            return exitWindowControl()
        }
        fistStartedAt = nil

        if configuration.twoHandResizeEnabled, hands.count >= 2,
           hands.prefix(2).allSatisfy(isOpenPalm),
           wristPoints.count == 2,
           resizeTracker.begin(wristPoints) != nil {
            mode = .windowResizing
            return result([.beginResizing], suppress: true)
        }

        guard let pinchDistance = normalizedPinch(hand), let indexTip = point("indexTip", in: hand) else {
            pinchStarted = false
            return result([], suppress: true)
        }
        if pinchDistance <= 0.32 {
            guard !pinchStarted else { return result([], suppress: true) }
            pinchStarted = true
            mode = .windowMoving
            return result([.beginMoving(anchor: indexTip)], suppress: true)
        }
        return result([], suppress: true)
    }

    private mutating func processMove(
        _ hand: [HandJoint],
        configuration: WindowGestureConfiguration
    ) -> WindowGestureResult {
        guard let pinchDistance = normalizedPinch(hand), let indexTip = point("indexTip", in: hand) else {
            pinchStarted = false
            mode = .windowControl
            return result([.endMoving], suppress: true)
        }
        guard pinchDistance < 0.48 else {
            pinchStarted = false
            mode = .windowControl
            return result([.endMoving], suppress: true)
        }
        return result([.moveWindow(position: indexTip, sensitivity: configuration.moveSensitivity)], suppress: true)
    }

    private mutating func processResize(
        hands: [[HandJoint]],
        configuration: WindowGestureConfiguration
    ) -> WindowGestureResult {
        let wristPoints = hands.prefix(2).compactMap(wristPoint)
        guard hands.count >= 2, hands.prefix(2).allSatisfy(isOpenPalm),
              wristPoints.count == 2,
              let scale = resizeTracker.scale(for: wristPoints) else {
            resizeTracker.reset()
            mode = .windowControl
            return result([.endResizing], suppress: true)
        }
        return result([.resizeWindow(scale: scale, smoothing: configuration.resizeSmoothing)], suppress: true)
    }

    private mutating func processAppSwipe(
        _ hand: [HandJoint],
        timestamp: TimeInterval,
        cooldown: TimeInterval
    ) -> WindowGestureResult {
        guard let centerX = fingerCenterX(hand) else { return result([], suppress: false) }
        guard let appSwipeStart else {
            self.appSwipeStart = (centerX, timestamp)
            mode = .appSwitching
            return result([], suppress: true)
        }
        let elapsed = timestamp - appSwipeStart.time
        let delta = centerX - appSwipeStart.x
        guard elapsed <= 0.65, abs(delta) >= 0.16,
              timestamp - lastAppSwitchAt >= cooldown else {
            if elapsed > 0.65 {
                self.appSwipeStart = (centerX, timestamp)
            }
            return result([], suppress: true)
        }
        lastAppSwitchAt = timestamp
        self.appSwipeStart = nil
        mode = .cursorControl
        return result([.switchApp(direction: delta < 0 ? 1 : -1)], suppress: true)
    }

    private mutating func exitWindowControl() -> WindowGestureResult {
        mode = .idle
        fistStartedAt = nil
        pinchStarted = false
        resizeTracker.reset()
        return result([.exitWindowControl], suppress: true)
    }

    private mutating func resetActiveGesture() -> [WindowGestureAction] {
        var actions: [WindowGestureAction] = []
        if mode == .windowMoving { actions.append(.endMoving) }
        if mode == .windowResizing { actions.append(.endResizing) }
        if mode == .windowControl || mode == .windowMoving || mode == .windowResizing {
            actions.append(.exitWindowControl)
        }
        mode = .idle
        palmStartedAt = nil
        fistStartedAt = nil
        pinchStarted = false
        appSwipeStart = nil
        resizeTracker.reset()
        return actions
    }

    private func result(
        _ actions: [WindowGestureAction],
        suppress: Bool,
        mode overrideMode: WindowGestureMode? = nil
    ) -> WindowGestureResult {
        WindowGestureResult(actions: actions, suppressCursor: suppress, mode: overrideMode ?? mode)
    }

    private func isOpenPalm(_ hand: [HandJoint]) -> Bool {
        ["index", "middle", "ring", "little"].allSatisfy { finger in
            guard let tip = point("\(finger)Tip", in: hand), let mcp = point("\(finger)MCP", in: hand),
                  let wrist = wristPoint(hand) else { return false }
            let palm = max(distance(mcp, wrist), 0.001)
            return distance(tip, mcp) > palm * 0.65
        }
    }

    private func isFist(_ hand: [HandJoint]) -> Bool {
        ["index", "middle", "ring", "little"].allSatisfy { finger in
            guard let tip = point("\(finger)Tip", in: hand), let mcp = point("\(finger)MCP", in: hand),
                  let wrist = wristPoint(hand) else { return false }
            let palm = max(distance(mcp, wrist), 0.001)
            return distance(tip, mcp) < palm * 0.55
        }
    }

    private func isThreeFingerPose(_ hand: [HandJoint]) -> Bool {
        ["index", "middle", "ring"].allSatisfy { finger in
            guard let tip = point("\(finger)Tip", in: hand), let mcp = point("\(finger)MCP", in: hand),
                  let wrist = wristPoint(hand) else { return false }
            return distance(tip, mcp) > distance(mcp, wrist) * 0.65
        }
    }

    private func normalizedPinch(_ hand: [HandJoint]) -> Double? {
        guard let thumb = point("thumbTip", in: hand), let index = point("indexTip", in: hand),
              let wrist = wristPoint(hand), let mcp = point("indexMCP", in: hand) else { return nil }
        return distance(thumb, index) / max(distance(wrist, mcp), 0.001)
    }

    private func fingerCenterX(_ hand: [HandJoint]) -> Double? {
        let tips = ["index", "middle", "ring"].compactMap { point("\($0)Tip", in: hand)?.x }
        guard tips.count == 3 else { return nil }
        return tips.reduce(0, +) / Double(tips.count)
    }

    private func wristPoint(_ hand: [HandJoint]) -> CGPoint? { point("wrist", in: hand) }

    private func point(_ name: String, in hand: [HandJoint]) -> CGPoint? {
        guard let joint = hand.first(where: { $0.name.contains(name) }) else { return nil }
        return CGPoint(x: joint.normalizedX, y: joint.normalizedY)
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
