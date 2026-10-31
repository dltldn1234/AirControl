import Combine
import CoreGraphics
import Foundation

struct NormalizedCursorArea: Codable, Equatable {
    var originX: Double
    var originY: Double
    var width: Double
    var height: Double

    static let standard = NormalizedCursorArea(originX: 0.08, originY: 0.08, width: 0.84, height: 0.84)

    var isValid: Bool {
        originX.isFinite && originY.isFinite && width.isFinite && height.isFinite
            && originX >= 0 && originY >= 0 && width > 0 && height > 0
            && originX + width <= 1 && originY + height <= 1
    }

    var cgRect: CGRect { CGRect(x: originX, y: originY, width: width, height: height) }
}

struct CursorCalibrationProfile: Codable, Equatable {
    var activeArea = NormalizedCursorArea.standard
    var pinchStartThreshold = 0.32
    var pinchReleaseThreshold = 0.48
    var mirrorsCamera = true
    var handScale = 0.2
    var isCalibrated = false

    static func load(from defaults: UserDefaults = .standard) -> CursorCalibrationProfile {
        guard let data = defaults.data(forKey: "cursorCalibrationProfile"),
              let profile = try? JSONDecoder().decode(CursorCalibrationProfile.self, from: data) else {
            return CursorCalibrationProfile()
        }
        return profile
    }

    func save(to defaults: UserDefaults = .standard) {
        guard activeArea.isValid,
              pinchStartThreshold.isFinite,
              pinchReleaseThreshold.isFinite,
              pinchStartThreshold > 0,
              pinchReleaseThreshold > pinchStartThreshold else { return }
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "cursorCalibrationProfile")
        defaults.set(activeArea.originX, forKey: "cursorActiveAreaX")
        defaults.set(activeArea.originY, forKey: "cursorActiveAreaY")
        defaults.set(activeArea.width, forKey: "cursorActiveAreaWidth")
        defaults.set(activeArea.height, forKey: "cursorActiveAreaHeight")
        defaults.set(pinchStartThreshold, forKey: "calibratedPinchStartThreshold")
        defaults.set(pinchReleaseThreshold, forKey: "calibratedPinchReleaseThreshold")
        defaults.set(mirrorsCamera, forKey: "cursorCameraMirrored")
    }
}

enum CalibrationStep: String, CaseIterable, Identifiable {
    case leftEdge
    case rightEdge
    case topEdge
    case bottomEdge
    case openPinch
    case closedPinch

    var id: String { rawValue }

    var instruction: String {
        switch self {
        case .leftEdge: "Move your index fingertip to the left edge of your comfortable range, then capture."
        case .rightEdge: "Move your index fingertip to the right edge of your comfortable range, then capture."
        case .topEdge: "Move your index fingertip to the top edge of your comfortable range, then capture."
        case .bottomEdge: "Move your index fingertip to the bottom edge of your comfortable range, then capture."
        case .openPinch: "Keep thumb and index apart in a relaxed open pose, then capture."
        case .closedPinch: "Make a comfortable thumb-index pinch, then capture."
        }
    }
}

enum CalibrationMath {
    static func activeArea(
        left: CGPoint,
        right: CGPoint,
        top: CGPoint,
        bottom: CGPoint,
        inset: Double = 0.015
    ) -> NormalizedCursorArea? {
        let minimumX = max(min(left.x, right.x) + inset, 0)
        let maximumX = min(max(left.x, right.x) - inset, 1)
        let minimumY = max(min(bottom.y, top.y) + inset, 0)
        let maximumY = min(max(bottom.y, top.y) - inset, 1)
        guard maximumX - minimumX >= 0.2, maximumY - minimumY >= 0.2 else { return nil }
        return NormalizedCursorArea(
            originX: minimumX,
            originY: minimumY,
            width: maximumX - minimumX,
            height: maximumY - minimumY
        )
    }

    static func pinchThresholds(openDistance: Double, closedDistance: Double) -> (start: Double, release: Double)? {
        guard openDistance.isFinite,
              closedDistance.isFinite,
              openDistance > closedDistance,
              openDistance - closedDistance >= 0.08 else { return nil }
        let range = openDistance - closedDistance
        return (closedDistance + range * 0.35, closedDistance + range * 0.55)
    }
}

@MainActor
final class CalibrationManager: ObservableObject {
    static let shared = CalibrationManager()

    @Published private(set) var profile: CursorCalibrationProfile
    @Published private(set) var currentStep: CalibrationStep?
    @Published private(set) var statusMessage: String

    private var latestSample: CalibrationSample?
    private var capturedPoints: [CalibrationStep: CGPoint] = [:]
    private var openPinchDistance: Double?

    private init() {
        let loadedProfile = CursorCalibrationProfile.load()
        profile = loadedProfile
        statusMessage = loadedProfile.isCalibrated ? "Calibration loaded." : "Using the default hand-control range."
    }

    func observe(_ hands: [[HandJoint]]) {
        latestSample = CalibrationSample(hands: hands)
    }

    func startWizard() {
        capturedPoints = [:]
        openPinchDistance = nil
        currentStep = .leftEdge
        statusMessage = currentStep?.instruction ?? ""
    }

    func captureCurrentStep() {
        guard let currentStep else { return }
        guard let latestSample else {
            statusMessage = "Start the camera and show a clearly tracked hand before capturing."
            return
        }

        switch currentStep {
        case .leftEdge, .rightEdge, .topEdge, .bottomEdge:
            let normalizedX = profile.mirrorsCamera ? 1 - latestSample.indexTip.x : latestSample.indexTip.x
            capturedPoints[currentStep] = CGPoint(x: normalizedX, y: latestSample.indexTip.y)
        case .openPinch:
            openPinchDistance = latestSample.pinchDistance
        case .closedPinch:
            guard let openPinchDistance,
                  CalibrationMath.pinchThresholds(
                    openDistance: openPinchDistance,
                    closedDistance: latestSample.pinchDistance
                  ) != nil else {
                statusMessage = "Pinch sample must be clearly closer than the open-hand sample. Capture again."
                return
            }
        }

        guard let nextIndex = CalibrationStep.allCases.firstIndex(of: currentStep).map({ $0 + 1 }) else { return }
        if nextIndex < CalibrationStep.allCases.count {
            self.currentStep = CalibrationStep.allCases[nextIndex]
            statusMessage = self.currentStep?.instruction ?? ""
        } else {
            finishWizard(closedPinchDistance: latestSample.pinchDistance)
        }
    }

    func setMirrorsCamera(_ mirrored: Bool) {
        profile.mirrorsCamera = mirrored
        let status = profile.isCalibrated ? "Mirror setting saved with the calibration." : "Mirror setting saved."
        saveProfile(status: status)
    }

    func reset() {
        profile = CursorCalibrationProfile()
        currentStep = nil
        capturedPoints = [:]
        openPinchDistance = nil
        profile.save()
        UserDefaults.standard.removeObject(forKey: "cursorCalibrationProfile")
        statusMessage = "Calibration reset to defaults."
    }

    private func finishWizard(closedPinchDistance: Double) {
        guard let left = capturedPoints[.leftEdge],
              let right = capturedPoints[.rightEdge],
              let top = capturedPoints[.topEdge],
              let bottom = capturedPoints[.bottomEdge],
              let openPinchDistance,
              let area = CalibrationMath.activeArea(left: left, right: right, top: top, bottom: bottom),
              let thresholds = CalibrationMath.pinchThresholds(
                openDistance: openPinchDistance,
                closedDistance: closedPinchDistance
              ) else {
            statusMessage = "Calibration samples were too close together. Start again and use a wider range."
            currentStep = nil
            return
        }
        guard area.isValid, thresholds.start < thresholds.release else {
            statusMessage = "Calibration values are invalid. Start again and keep the hand inside the camera view."
            currentStep = nil
            return
        }
        profile.activeArea = area
        profile.pinchStartThreshold = thresholds.start
        profile.pinchReleaseThreshold = thresholds.release
        profile.handScale = latestSample?.palmScale ?? profile.handScale
        profile.isCalibrated = true
        currentStep = nil
        saveProfile(status: "Calibration saved for this Mac user.")
    }

    private func saveProfile(status: String) {
        profile.save()
        statusMessage = status
    }
}

private struct CalibrationSample {
    let indexTip: CGPoint
    let pinchDistance: Double
    let palmScale: Double

    init?(hands: [[HandJoint]]) {
        for joints in hands {
            guard let indexTip = Self.point("indexTip", joints: joints, minimumConfidence: 0.55),
                  let thumbTip = Self.point("thumbTip", joints: joints),
                  let indexMCP = Self.point("indexMCP", joints: joints),
                  let wrist = Self.point("wrist", joints: joints) else { continue }
            let palmScale = max(Self.distance(indexMCP, wrist), 0.001)
            self.indexTip = indexTip
            self.palmScale = palmScale
            pinchDistance = Self.distance(indexTip, thumbTip) / palmScale
            return
        }
        return nil
    }

    private static func point(_ name: String, joints: [HandJoint], minimumConfidence: Double = 0.25) -> CGPoint? {
        guard let joint = joints.first(where: { $0.name == name && $0.confidence >= minimumConfidence }) else {
            return nil
        }
        return CGPoint(x: joint.normalizedX, y: joint.normalizedY)
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
