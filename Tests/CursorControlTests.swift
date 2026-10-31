import CoreGraphics
import Testing
@testable import AirControl

struct CursorControlTests {
    @Test
    func coordinateMappingMirrorsAndClampsToDisplayBounds() {
        let bounds = CGRect(x: -1000, y: 0, width: 2000, height: 1000)

        let center = CursorCoordinateMapper.map(
            normalizedX: 0.5,
            normalizedY: 0.5,
            displayBounds: bounds
        )
        let mirroredEdge = CursorCoordinateMapper.map(
            normalizedX: 0,
            normalizedY: 0.5,
            displayBounds: bounds
        )

        #expect(center == CGPoint(x: 0, y: 500))
        #expect(mirroredEdge == CGPoint(x: 1000, y: 500))
    }

    @Test
    func smootherUsesEmaAndIgnoresDeadZoneNoise() {
        var smoother = CursorSmoother()
        _ = smoother.apply(CGPoint(x: 100, y: 100), alpha: 0.5, deadZone: 2)

        let noisy = smoother.apply(CGPoint(x: 101, y: 100), alpha: 0.5, deadZone: 2)
        let moved = smoother.apply(CGPoint(x: 110, y: 100), alpha: 0.5, deadZone: 2)

        #expect(noisy == CGPoint(x: 100, y: 100))
        #expect(moved == CGPoint(x: 105, y: 100))
    }

    @Test
    func cursorInputRequiresBothExplicitEnablementAndAccessibilityTrust() {
        #expect(!CursorPermissionGate.allowsInput(isEnabled: false, isTrusted: true))
        #expect(!CursorPermissionGate.allowsInput(isEnabled: true, isTrusted: false))
        #expect(CursorPermissionGate.allowsInput(isEnabled: true, isTrusted: true))
    }

    @Test
    func oneEuroFilterKeepsSubDeadZoneNoiseStill() {
        var filter = OneEuroCursorFilter()
        let initial = CGPoint(x: 400, y: 300)
        _ = filter.apply(initial, timestamp: 1)
        let output = filter.apply(
            CGPoint(x: 401, y: 300),
            timestamp: 1.02,
            configuration: CursorFilterConfiguration(deadZone: 2)
        )

        #expect(output == initial)
    }

    @Test
    func oneEuroFilterAdaptsToFasterMovement() {
        var steadyFilter = OneEuroCursorFilter()
        var adaptiveFilter = OneEuroCursorFilter()
        _ = steadyFilter.apply(.zero, timestamp: 1)
        _ = adaptiveFilter.apply(.zero, timestamp: 1)

        let steady = steadyFilter.apply(
            CGPoint(x: 100, y: 0),
            timestamp: 1.02,
            configuration: CursorFilterConfiguration(minimumCutoff: 1, beta: 0, deadZone: 0)
        )
        let adaptive = adaptiveFilter.apply(
            CGPoint(x: 100, y: 0),
            timestamp: 1.02,
            configuration: CursorFilterConfiguration(minimumCutoff: 1, beta: 0.1, deadZone: 0)
        )

        #expect(adaptive.x > steady.x)
    }

    @Test
    func oneEuroFilterLimitsSuddenCoordinateOutliers() {
        var filter = OneEuroCursorFilter()
        _ = filter.apply(CGPoint(x: 100, y: 100), timestamp: 1)
        _ = filter.apply(
            CGPoint(x: 5_000, y: 100),
            timestamp: 1.02,
            configuration: CursorFilterConfiguration(
                minimumCutoff: 1,
                beta: 0,
                deadZone: 0,
                maximumSpeed: 100_000,
                maximumJump: 100
            )
        )

        #expect(filter.previousRawPoint?.x == 200)
    }
}
