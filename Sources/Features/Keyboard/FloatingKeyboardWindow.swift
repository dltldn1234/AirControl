import AppKit
import SwiftUI

@MainActor
final class FloatingKeyboardWindow {
    private var panel: NSPanel?
    private weak var coordinator: AirKeyboardCoordinator?
    private var scale = 1.0

    var keyboardSurfaceFrame: CGRect? {
        guard let panel else { return nil }
        let frame = panel.frame
        return CGRect(
            x: frame.minX + 14,
            y: frame.minY + 14,
            width: frame.width - 28,
            height: max(frame.height - 62, 1)
        )
    }

    var screenFrame: CGRect? {
        panel?.screen?.frame ?? NSScreen.main?.frame
    }

    func show(coordinator: AirKeyboardCoordinator, scale: Double, opacity: Double) {
        self.coordinator = coordinator
        self.scale = min(max(scale, 0.75), 1.35)
        if panel == nil {
            createPanel(coordinator: coordinator)
        }
        guard let panel else { return }
        applySize(to: panel, scale: self.scale, reposition: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            panel.animator().alphaValue = min(max(opacity, 0.5), 1)
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
            panel?.alphaValue = 1
        })
    }

    func hideImmediately() {
        panel?.orderOut(nil)
        panel?.alphaValue = 1
    }

    func updateAppearance(scale: Double, opacity: Double) {
        guard let panel else { return }
        let newScale = min(max(scale, 0.75), 1.35)
        if abs(newScale - self.scale) > 0.001 {
            self.scale = newScale
            applySize(to: panel, scale: newScale, reposition: false)
        }
        if panel.isVisible {
            panel.animator().alphaValue = min(max(opacity, 0.5), 1)
        }
    }

    func resetPosition() {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return }
        let frame = panel.frame
        panel.setFrame(
            NSRect(
                x: screen.visibleFrame.midX - frame.width / 2,
                y: screen.visibleFrame.minY + 28,
                width: frame.width,
                height: frame.height
            ),
            display: true,
            animate: true
        )
    }

    private func createPanel(coordinator: AirKeyboardCoordinator) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 290),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.minSize = NSSize(width: 600, height: 250)
        panel.maxSize = NSSize(width: 1_100, height: 440)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .utilityWindow
        panel.contentView = NSHostingView(rootView: AirKeyboardPanelView(coordinator: coordinator))
        self.panel = panel
    }

    private func applySize(to panel: NSPanel, scale: Double, reposition: Bool) {
        let screen = panel.screen ?? NSScreen.main
        let center = reposition
            ? CGPoint(x: screen?.visibleFrame.midX ?? 0, y: (screen?.visibleFrame.minY ?? 0) + 28)
            : CGPoint(x: panel.frame.midX, y: panel.frame.midY)
        let width = 760 * scale
        let height = 290 * scale
        panel.setFrame(
            NSRect(x: center.x - width / 2, y: center.y, width: width, height: height),
            display: true,
            animate: true
        )
    }
}
