import CoreGraphics
import Foundation

enum AirKeyboardInteractionState: String, Equatable {
    case inactive = "Keyboard inactive"
    case active = "Keyboard active"
    case keyHover = "Selecting key"
    case keyPressed = "Key selected"
}

struct AirKeyboardGestureResult: Equatable {
    let state: AirKeyboardInteractionState
    let hoveredKeyID: String?
    let activatedKeyID: String?
    let isHandTracked: Bool
}

private struct AirKeyboardGestureContext {
    let rows: [[AirKeyboardKey]]
    let keyboardFrame: CGRect
    let screenFrame: CGRect
    let sensitivity: Double
    let timestamp: TimeInterval
}

struct AirKeyboardPointerMapper {
    static func map(
        normalizedX: Double,
        normalizedY: Double,
        screenFrame: CGRect,
        mirrored: Bool = true,
        sensitivity: Double = 1
    ) -> CGPoint {
        let sourceX = mirrored ? 1 - normalizedX : normalizedX
        let gain = min(max(sensitivity, 0.6), 1.6)
        let normalizedScreenX = min(max((sourceX - 0.5) * gain + 0.5, 0), 1)
        let normalizedScreenY = min(max((normalizedY - 0.5) * gain + 0.5, 0), 1)
        return CGPoint(
            x: screenFrame.minX + normalizedScreenX * screenFrame.width,
            y: screenFrame.minY + normalizedScreenY * screenFrame.height
        )
    }
}

struct AirKeyboardHitTester {
    private static let keySpacing: CGFloat = 6

    static func key(
        at point: CGPoint,
        rows: [[AirKeyboardKey]],
        frame: CGRect,
        previousKeyID: String? = nil,
        hysteresis: CGFloat = 7
    ) -> AirKeyboardKey? {
        guard frame.contains(point), !rows.isEmpty else { return nil }

        if let previousKeyID,
           let previousFrame = keyFrame(id: previousKeyID, rows: rows, frame: frame),
           previousFrame.insetBy(dx: -hysteresis, dy: -hysteresis).contains(point),
           let previousKey = rows.joined().first(where: { $0.id == previousKeyID }) {
            return previousKey
        }

        let rowHeight = (frame.height - keySpacing * CGFloat(rows.count - 1)) / CGFloat(rows.count)
        let rowStride = rowHeight + keySpacing
        let rowOffset = (point.y - frame.minY).truncatingRemainder(dividingBy: rowStride)
        guard rowOffset <= rowHeight else { return nil }
        let bottomRow = min(max(Int((point.y - frame.minY) / rowStride), 0), rows.count - 1)
        let rowIndex = rows.count - 1 - bottomRow
        let row = rows[rowIndex]
        guard !row.isEmpty else { return nil }
        let keyWidth = (frame.width - keySpacing * CGFloat(row.count - 1)) / CGFloat(row.count)
        let keyStride = keyWidth + keySpacing
        let keyOffset = (point.x - frame.minX).truncatingRemainder(dividingBy: keyStride)
        guard keyOffset <= keyWidth else { return nil }
        let column = min(max(Int((point.x - frame.minX) / keyStride), 0), row.count - 1)
        return row[column]
    }

    private static func keyFrame(id: String, rows: [[AirKeyboardKey]], frame: CGRect) -> CGRect? {
        guard let rowIndex = rows.firstIndex(where: { $0.contains { $0.id == id } }),
              let row = rows.first(where: { $0.contains { $0.id == id } }),
              let column = row.firstIndex(where: { $0.id == id }),
              !row.isEmpty, !rows.isEmpty else { return nil }
        let width = (frame.width - keySpacing * CGFloat(row.count - 1)) / CGFloat(row.count)
        let height = (frame.height - keySpacing * CGFloat(rows.count - 1)) / CGFloat(rows.count)
        let bottomRow = rows.count - rowIndex - 1
        return CGRect(
            x: frame.minX + CGFloat(column) * (width + keySpacing),
            y: frame.minY + CGFloat(bottomRow) * (height + keySpacing),
            width: width,
            height: height
        )
    }
}

struct AirKeyboardGestureRecognizer {
    private(set) var state: AirKeyboardInteractionState = .inactive
    private(set) var hoveredKeyID: String?
    private var isPinching = false
    private var lastActivationTime = -Double.infinity

    mutating func setActive(_ active: Bool) {
        reset()
        state = active ? .active : .inactive
    }

    mutating func process(
        hands: [[HandJoint]],
        rows: [[AirKeyboardKey]],
        keyboardFrame: CGRect,
        screenFrame: CGRect,
        sensitivity: Double = 1,
        timestamp: TimeInterval
    ) -> AirKeyboardGestureResult {
        guard state != .inactive else { return result(isHandTracked: false, activatedKeyID: nil) }
        guard let pose = KeyboardHandPose(hands: hands) else { return trackingLossResult() }
        return processPose(pose, context: AirKeyboardGestureContext(
            rows: rows,
            keyboardFrame: keyboardFrame,
            screenFrame: screenFrame,
            sensitivity: sensitivity,
            timestamp: timestamp
        ))
    }

    private mutating func processPose(
        _ pose: KeyboardHandPose,
        context: AirKeyboardGestureContext
    ) -> AirKeyboardGestureResult {
        let screenPoint = AirKeyboardPointerMapper.map(
            normalizedX: pose.indexTip.x,
            normalizedY: pose.indexTip.y,
            screenFrame: context.screenFrame,
            sensitivity: context.sensitivity
        )
        let key = AirKeyboardHitTester.key(
            at: screenPoint,
            rows: context.rows,
            frame: context.keyboardFrame,
            previousKeyID: hoveredKeyID
        )
        hoveredKeyID = key?.id

        var activatedKeyID: String?
        if isPinching {
            if pose.pinchDistance >= 0.48 { isPinching = false }
        } else if pose.pinchDistance <= 0.32 {
            isPinching = true
            if context.timestamp - lastActivationTime >= 0.2, let key {
                activatedKeyID = key.id
                lastActivationTime = context.timestamp
            }
        }

        if isPinching {
            state = .keyPressed
        } else if key != nil {
            state = .keyHover
        } else {
            state = .active
        }
        return result(isHandTracked: true, activatedKeyID: activatedKeyID)
    }

    private mutating func trackingLossResult() -> AirKeyboardGestureResult {
        isPinching = false
        hoveredKeyID = nil
        state = .active
        return result(isHandTracked: false, activatedKeyID: nil)
    }

    private func result(isHandTracked: Bool, activatedKeyID: String?) -> AirKeyboardGestureResult {
        AirKeyboardGestureResult(
            state: state,
            hoveredKeyID: hoveredKeyID,
            activatedKeyID: activatedKeyID,
            isHandTracked: isHandTracked
        )
    }

    mutating func reset() {
        isPinching = false
        hoveredKeyID = nil
        if state != .inactive { state = .active }
    }
}

private struct KeyboardHandPose {
    let indexTip: CGPoint
    let pinchDistance: Double

    init?(hands: [[HandJoint]]) {
        for joints in hands {
            guard let tip = Self.point("indexTip", in: joints, minimumConfidence: 0.55),
                  let thumb = Self.point("thumbTip", in: joints),
                  let wrist = Self.point("wrist", in: joints),
                  let indexMCP = Self.point("indexMCP", in: joints) else { continue }
            indexTip = tip
            pinchDistance = Self.distance(tip, thumb) / max(Self.distance(indexMCP, wrist), 0.001)
            return
        }
        return nil
    }

    private static func point(_ name: String, in joints: [HandJoint], minimumConfidence: Double = 0.25) -> CGPoint? {
        guard let joint = joints.first(where: { $0.name == name && $0.confidence >= minimumConfidence }) else {
            return nil
        }
        return CGPoint(x: joint.normalizedX, y: joint.normalizedY)
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
