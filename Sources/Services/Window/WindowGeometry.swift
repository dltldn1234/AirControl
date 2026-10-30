import CoreGraphics
import Foundation

struct WindowFrame: Equatable {
    var originX: Double
    var originY: Double
    var width: Double
    var height: Double

    var center: CGPoint { CGPoint(x: originX + width / 2, y: originY + height / 2) }
}

enum WindowGeometry {
    static func handDelta(
        from start: CGPoint,
        to current: CGPoint,
        displayBounds: CGRect,
        sensitivity: Double
    ) -> CGPoint {
        CGPoint(
            x: (current.x - start.x) * displayBounds.width * sensitivity,
            y: -(current.y - start.y) * displayBounds.height * sensitivity
        )
    }

    static func interHandDistance(_ first: CGPoint, _ second: CGPoint) -> Double {
        hypot(first.x - second.x, first.y - second.y)
    }

    static func resized(
        _ frame: WindowFrame,
        scale: Double,
        minimumSize: CGSize,
        maximumSize: CGSize,
        displayBounds: CGRect
    ) -> WindowFrame {
        let maximumWidth = max(1, min(maximumSize.width, displayBounds.width))
        let maximumHeight = max(1, min(maximumSize.height, displayBounds.height))
        let minimumWidth = min(max(1, minimumSize.width), maximumWidth)
        let minimumHeight = min(max(1, minimumSize.height), maximumHeight)
        let width = min(max(frame.width * scale, minimumWidth), maximumWidth)
        let height = min(max(frame.height * scale, minimumHeight), maximumHeight)
        let center = frame.center
        return clamped(
            WindowFrame(
                originX: center.x - width / 2,
                originY: center.y - height / 2,
                width: width,
                height: height
            ),
            within: displayBounds
        )
    }

    static func clamped(_ frame: WindowFrame, within bounds: CGRect) -> WindowFrame {
        let width = min(max(frame.width, 1), bounds.width)
        let height = min(max(frame.height, 1), bounds.height)
        return WindowFrame(
            originX: min(max(frame.originX, bounds.minX), bounds.maxX - width),
            originY: min(max(frame.originY, bounds.minY), bounds.maxY - height),
            width: width,
            height: height
        )
    }

    static func accessibilityDisplayBounds(
        screenFrames: [CGRect],
        primaryScreenFrame: CGRect
    ) -> CGRect {
        let converted = screenFrames.map { frame in
            CGRect(
                x: frame.minX,
                y: primaryScreenFrame.maxY - frame.maxY,
                width: frame.width,
                height: frame.height
            )
        }
        return converted.dropFirst().reduce(converted.first ?? .zero) { $0.union($1) }
    }
}

enum WindowPermissionGate {
    static func allowsWindowControl(isTrusted: Bool, positionSettable: Bool, sizeSettable: Bool) -> Bool {
        isTrusted && (positionSettable || sizeSettable)
    }
}
