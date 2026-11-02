import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct WindowTargetInfo: Equatable {
    let applicationName: String
    let windowTitle: String
    let frame: WindowFrame
}

final class WindowManager {
    private var selectedWindow: AXUIElement?
    private var cachedTargetInfo: WindowTargetInfo?
    private var moveStartFrame: WindowFrame?
    private var moveAnchor: CGPoint?
    private var resizeStartFrame: WindowFrame?
    private var minimumWindowSize = CGSize(width: 160, height: 120)
    private var maximumWindowSize = CGSize.zero
    private var positionAttributeSettable = false
    private var sizeAttributeSettable = false
    private var lastAXOperation = 0.0
    private let minimumOperationInterval = 1.0 / 30

    var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    var displayBounds: CGRect {
        let frames = NSScreen.screens.map(\.frame)
        let primary = NSScreen.screens.first?.frame ?? .zero
        return WindowGeometry.accessibilityDisplayBounds(screenFrames: frames, primaryScreenFrame: primary)
    }

    func selectActiveWindow() -> WindowTargetInfo? {
        guard let (application, window) = focusedWindow() else {
            clearSelection()
            return nil
        }
        positionAttributeSettable = isPositionSettable(window)
        sizeAttributeSettable = isSizeSettable(window)
        guard WindowPermissionGate.allowsWindowControl(
            isTrusted: isAccessibilityTrusted,
            positionSettable: positionAttributeSettable,
            sizeSettable: sizeAttributeSettable
        ), let frame = readFrame(window) else {
            clearSelection()
            return nil
        }
        selectedWindow = window
        let info = WindowTargetInfo(
            applicationName: stringAttribute(application, kAXTitleAttribute as CFString) ?? "Active application",
            windowTitle: stringAttribute(window, kAXTitleAttribute as CFString) ?? "Untitled window",
            frame: frame
        )
        cachedTargetInfo = info
        return info
    }

    func selectedTargetInfo() -> WindowTargetInfo? {
        guard isAccessibilityTrusted, selectedWindow != nil else { return nil }
        return cachedTargetInfo
    }

    func beginMoving(at anchor: CGPoint) -> WindowTargetInfo? {
        guard let info = selectActiveWindow(), positionAttributeSettable else { return nil }
        moveStartFrame = info.frame
        moveAnchor = anchor
        return info
    }

    func moveSelectedWindow(to handPosition: CGPoint, sensitivity: Double) -> WindowTargetInfo? {
        guard let moveStartFrame, let moveAnchor, let selectedWindow,
              isAccessibilityTrusted, positionAttributeSettable else { return nil }
        let delta = WindowGeometry.handDelta(
            from: moveAnchor,
            to: handPosition,
            displayBounds: displayBounds,
            sensitivity: sensitivity
        )
        let frame = WindowGeometry.clamped(
            WindowFrame(
                originX: moveStartFrame.originX + delta.x,
                originY: moveStartFrame.originY + delta.y,
                width: moveStartFrame.width,
                height: moveStartFrame.height
            ),
            within: displayBounds
        )
        guard canPerformAXOperation(),
              setPoint(
                CGPoint(x: frame.originX, y: frame.originY),
                on: selectedWindow,
                attribute: kAXPositionAttribute
              ) else {
            return nil
        }
        let target = WindowTargetInfo(
            applicationName: cachedTargetInfo?.applicationName ?? "Active application",
            windowTitle: cachedTargetInfo?.windowTitle ?? "Untitled window",
            frame: frame
        )
        cachedTargetInfo = target
        return target
    }

    func beginResizing() -> WindowTargetInfo? {
        guard let info = selectActiveWindow(), let selectedWindow, sizeAttributeSettable else { return nil }
        resizeStartFrame = info.frame
        let limits = readSizeLimits(selectedWindow)
        minimumWindowSize = limits.minimum
        maximumWindowSize = limits.maximum
        return info
    }

    func resizeSelectedWindow(fromScale scale: Double, smoothing: Double) -> WindowTargetInfo? {
        guard canPerformAXOperation(), let selectedWindow, let resizeStartFrame,
              sizeAttributeSettable else { return nil }
        let adjusted = WindowGeometry.resized(
            resizeStartFrame,
            scale: scale,
            minimumSize: minimumWindowSize,
            maximumSize: maximumWindowSize,
            displayBounds: displayBounds
        )
        let current = cachedTargetInfo?.frame ?? resizeStartFrame
        let alpha = min(max(smoothing, 0.05), 1)
        let size = CGSize(
            width: current.width + (adjusted.width - current.width) * alpha,
            height: current.height + (adjusted.height - current.height) * alpha
        )
        guard setSize(size, on: selectedWindow) else { return nil }
        let center = current.center
        let frame = WindowGeometry.clamped(
            WindowFrame(
                originX: center.x - size.width / 2,
                originY: center.y - size.height / 2,
                width: size.width,
                height: size.height
            ),
            within: displayBounds
        )
        if positionAttributeSettable {
            _ = setPoint(
                CGPoint(x: frame.originX, y: frame.originY),
                on: selectedWindow,
                attribute: kAXPositionAttribute
            )
        }
        let target = WindowTargetInfo(
            applicationName: cachedTargetInfo?.applicationName ?? "Active application",
            windowTitle: cachedTargetInfo?.windowTitle ?? "Untitled window",
            frame: frame
        )
        cachedTargetInfo = target
        return target
    }

    func endManipulation() {
        moveStartFrame = nil
        moveAnchor = nil
        resizeStartFrame = nil
        minimumWindowSize = CGSize(width: 160, height: 120)
        maximumWindowSize = .zero
    }

    func clearSelection() {
        selectedWindow = nil
        cachedTargetInfo = nil
        positionAttributeSettable = false
        sizeAttributeSettable = false
    }

    private func canPerformAXOperation() -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastAXOperation >= minimumOperationInterval, isAccessibilityTrusted else { return false }
        lastAXOperation = now
        return true
    }

    private func focusedWindow() -> (AXUIElement, AXUIElement)? {
        guard let application = focusedApplication() else { return nil }
        _ = AXUIElementSetMessagingTimeout(application, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let window = accessibilityElement(value) else { return nil }
        return (application, window)
    }

    private func focusedApplication() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        _ = AXUIElementSetMessagingTimeout(system, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system,
            kAXFocusedApplicationAttribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        guard let application = accessibilityElement(value) else { return nil }
        _ = AXUIElementSetMessagingTimeout(application, 0.2)
        return application
    }

    private func readFrame(_ window: AXUIElement) -> WindowFrame? {
        guard let point = pointAttribute(window, kAXPositionAttribute),
              let size = sizeAttribute(window, kAXSizeAttribute) else { return nil }
        return WindowFrame(originX: point.x, originY: point.y, width: size.width, height: size.height)
    }

    private func isPositionSettable(_ window: AXUIElement) -> Bool {
        isAttributeSettable(window, kAXPositionAttribute)
    }

    private func isSizeSettable(_ window: AXUIElement) -> Bool {
        isAttributeSettable(window, kAXSizeAttribute)
    }

    private func isAttributeSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return result == .success && settable.boolValue
    }

    private func pointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let value = valueAttribute(element, attribute),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func sizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let value = valueAttribute(element, attribute),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    private func valueAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private func readSizeLimits(_ window: AXUIElement) -> (minimum: CGSize, maximum: CGSize) {
        let minimum = sizeAttribute(window, "AXMinSize") ?? CGSize(width: 160, height: 120)
        let maximum = sizeAttribute(window, "AXMaxSize")
            ?? CGSize(width: displayBounds.width, height: displayBounds.height)
        return (minimum, maximum)
    }

    private func accessibilityElement(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func setPoint(_ point: CGPoint, on element: AXUIElement, attribute: String) -> Bool {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
    }

    private func setSize(_ size: CGSize, on element: AXUIElement) -> Bool {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value) == .success
    }
}
