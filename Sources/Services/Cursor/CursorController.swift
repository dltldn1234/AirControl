import ApplicationServices
import CoreGraphics

struct CursorPermissionGate {
    static func allowsInput(isEnabled: Bool, isTrusted: Bool) -> Bool {
        isEnabled && isTrusted
    }
}

final class CursorController {
    private let eventQueue = DispatchQueue(label: "aircontrol.cursor.events", qos: .userInteractive)
    private var smoother = CursorSmoother()
    private var isEnabled = false
    private var isDragging = false

    var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    func requestAccessibilityAccess() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if enabled, !isAccessibilityTrusted {
            _ = requestAccessibilityAccess()
            return false
        }
        eventQueue.async { [weak self] in
            guard let self else { return }
            isEnabled = enabled
            if !enabled {
                releaseDrag()
                smoother.reset()
            }
        }
        return true
    }

    func move(to point: CGPoint, alpha: Double, deadZone: CGFloat = 2) {
        guard isAccessibilityTrusted else { return }
        eventQueue.async { [weak self] in
            guard let self,
                  CursorPermissionGate.allowsInput(
                    isEnabled: isEnabled,
                    isTrusted: isAccessibilityTrusted
                  ) else { return }
            let displayBounds = CGDisplayBounds(CGMainDisplayID()).insetBy(dx: 1, dy: 1)
            let boundedPoint = CGPoint(
                x: min(max(point.x, displayBounds.minX), displayBounds.maxX),
                y: min(max(point.y, displayBounds.minY), displayBounds.maxY)
            )
            let smoothedPoint = smoother.apply(boundedPoint, alpha: alpha, deadZone: deadZone)
            postMouseEvent(.mouseMoved, at: smoothedPoint)
        }
    }

    func beginDrag() {
        guard isAccessibilityTrusted else { return }
        eventQueue.async { [weak self] in
            guard let self, isEnabled, !isDragging, isAccessibilityTrusted,
                  let location = CGEvent(source: nil)?.location,
                  postMouseEvent(.leftMouseDown, at: location) else { return }
            isDragging = true
        }
    }

    func endDrag() {
        eventQueue.async { [weak self] in
            self?.releaseDrag()
        }
    }

    func scroll(delta: Double) {
        guard isAccessibilityTrusted else { return }
        eventQueue.async { [weak self] in
            guard let self,
                  CursorPermissionGate.allowsInput(
                    isEnabled: isEnabled,
                    isTrusted: isAccessibilityTrusted
                  ),
                  let event = CGEvent(
                    scrollWheelEvent2Source: nil,
                    units: .pixel,
                    wheelCount: 1,
                    wheel1: Int32(min(max(delta, -120), 120)),
                    wheel2: 0,
                    wheel3: 0
                  ) else { return }
            smoother.reset()
            event.post(tap: .cghidEventTap)
        }
    }

    func rightClick() {
        guard isAccessibilityTrusted else { return }
        eventQueue.async { [weak self] in
            guard let self, isEnabled, !isDragging, isAccessibilityTrusted,
                  let location = CGEvent(source: nil)?.location else { return }
            _ = postMouseEvent(.rightMouseDown, at: location, button: .right)
            _ = postMouseEvent(.rightMouseUp, at: location, button: .right)
        }
    }

    func click() {
        guard isAccessibilityTrusted else { return }
        eventQueue.async { [weak self] in
            guard let self, isEnabled, !isDragging, isAccessibilityTrusted,
                  let location = CGEvent(source: nil)?.location else { return }
            guard postMouseEvent(.leftMouseDown, at: location) else { return }
            _ = postMouseEvent(.leftMouseUp, at: location)
        }
    }

    func stop() {
        eventQueue.sync {
            isEnabled = false
            releaseDrag()
            smoother.reset()
        }
    }

    @discardableResult
    private func postMouseEvent(
        _ type: CGEventType,
        at point: CGPoint,
        button: CGMouseButton = .left
    ) -> Bool {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        ) else { return false }
        event.post(tap: .cghidEventTap)
        return true
    }

    private func releaseDrag() {
        guard isDragging else { return }
        if let location = CGEvent(source: nil)?.location {
            _ = postMouseEvent(.leftMouseUp, at: location)
        }
        isDragging = false
    }
}
