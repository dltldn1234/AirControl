import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct CursorPermissionGate {
    static func allowsInput(isEnabled: Bool, isTrusted: Bool) -> Bool {
        isEnabled && isTrusted
    }
}

enum MouseClickSequence {
    static let doubleClickStates: [Int64] = [1, 2]
}

enum MouseClickEventPair {
    @discardableResult
    static func post(
        down: CGEvent?,
        upEvent: CGEvent?,
        using postEvent: (CGEvent) -> Void
    ) -> Bool {
        guard let down, let upEvent else { return false }
        postEvent(down)
        postEvent(upEvent)
        return true
    }
}

final class CursorController {
    private let eventQueue = DispatchQueue(label: "aircontrol.cursor.events", qos: .userInteractive)
    private var smoother = OneEuroCursorFilter()
    private var isEnabled = false
    private var isDragging = false

    var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        if enabled, !isAccessibilityTrusted {
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
            let displays = DisplayCoordinateMapper.activeDisplayBounds()
            let displayBounds = DisplayCoordinateMapper.virtualBounds(for: displays)
            let boundedPoint = DisplayCoordinateMapper.constrain(point, to: displays)
            let filterConfiguration = CursorFilterConfiguration(
                minimumCutoff: 0.6 + alpha * 1.6,
                beta: 0.0008 + (1 - alpha) * 0.01,
                deadZone: deadZone,
                maximumSpeed: 5_000,
                maximumJump: max(displayBounds.width, displayBounds.height) * 0.35
            )
            let smoothedPoint = smoother.apply(
                boundedPoint,
                timestamp: ProcessInfo.processInfo.systemUptime,
                configuration: filterConfiguration
            )
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
            _ = postMouseClick(
                downType: .rightMouseDown,
                upType: .rightMouseUp,
                at: location,
                button: .right
            )
        }
    }

    func click() {
        guard isAccessibilityTrusted else { return }
        eventQueue.async { [weak self] in
            guard let self, isEnabled, !isDragging, isAccessibilityTrusted,
                  let location = CGEvent(source: nil)?.location else { return }
            _ = postMouseClick(downType: .leftMouseDown, upType: .leftMouseUp, at: location)
        }
    }

    func doubleClick() {
        guard isAccessibilityTrusted else { return }
        eventQueue.async { [weak self] in
            guard let self, isEnabled, !isDragging, isAccessibilityTrusted,
                  let location = CGEvent(source: nil)?.location else { return }
            for clickState in MouseClickSequence.doubleClickStates {
                guard postMouseClick(
                    downType: .leftMouseDown,
                    upType: .leftMouseUp,
                    at: location,
                    clickState: clickState
                ) else { return }
            }
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
    private func postMouseClick(
        downType: CGEventType,
        upType: CGEventType,
        at point: CGPoint,
        button: CGMouseButton = .left,
        clickState: Int64 = 1
    ) -> Bool {
        let downEvent = makeMouseEvent(downType, at: point, button: button, clickState: clickState)
        let upEvent = makeMouseEvent(upType, at: point, button: button, clickState: clickState)
        return MouseClickEventPair.post(down: downEvent, upEvent: upEvent) {
            $0.post(tap: .cghidEventTap)
        }
    }

    private func makeMouseEvent(
        _ type: CGEventType,
        at point: CGPoint,
        button: CGMouseButton = .left,
        clickState: Int64 = 1
    ) -> CGEvent? {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        ) else { return nil }
        event.setIntegerValueField(.mouseEventClickState, value: clickState)
        return event
    }

    @discardableResult
    private func postMouseEvent(
        _ type: CGEventType,
        at point: CGPoint,
        button: CGMouseButton = .left
    ) -> Bool {
        guard let event = makeMouseEvent(type, at: point, button: button) else { return false }
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
