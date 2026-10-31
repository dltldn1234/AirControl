import Testing
import CoreGraphics
@testable import AirControl

struct AirKeyboardTests {
    @Test
    func englishAndKoreanLayoutsHaveExpectedRowsAndEditingKeys() {
        let english = AirKeyboardLayout.rows(for: .english)
        let korean = AirKeyboardLayout.rows(for: .korean)

        #expect(english.count == 5)
        #expect(english[1].map(\.label).joined() == "qwertyuiop")
        #expect(korean[1].map(\.label).joined() == "ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ")
        #expect(AirKeyboardLayout.rows(for: .english, shifted: true)[0].map(\.label).joined().hasPrefix("!@#$%^&*()"))
        #expect(AirKeyboardLayout.rows(for: .korean, shifted: true)[1].map(\.label).joined().hasPrefix("ㅃㅉㄸㄲㅆ"))
        #expect(english.flatMap { $0 }.contains { $0.action == .space })
        #expect(english.flatMap { $0 }.contains { $0.action == .backspace })
        #expect(english.flatMap { $0 }.contains { $0.action == .inputSourceToggle })
    }

    @Test
    func pointerMappingMirrorsCameraXCoordinate() {
        let point = AirKeyboardPointerMapper.map(
            normalizedX: 0.2,
            normalizedY: 0.35,
            screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )

        #expect(point.x == 80)
        #expect(point.y == 35)
    }

    @Test
    func hitTestingUsesTopFirstRowsAndHoldsPreviousKeyAtBoundary() {
        let rows = [[key("a"), key("b")], [key("c"), key("d")]]
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        #expect(AirKeyboardHitTester.key(at: CGPoint(x: 20, y: 80), rows: rows, frame: frame)?.id == "a")
        #expect(
            AirKeyboardHitTester.key(
                at: CGPoint(x: 52, y: 80),
                rows: rows,
                frame: frame,
                previousKeyID: "a"
            )?.id == "a"
        )
    }

    @Test
    func pinchActivatesOneKeyOnlyOnceUntilReleased() {
        var recognizer = AirKeyboardGestureRecognizer()
        recognizer.setActive(true)
        let rows = [[key("a"), key("b")]]
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        let first = recognizer.process(
            hands: [hand(thumbX: 0.76)], rows: rows, keyboardFrame: frame, screenFrame: frame, timestamp: 1
        )
        let held = recognizer.process(
            hands: [hand(thumbX: 0.76)], rows: rows, keyboardFrame: frame, screenFrame: frame, timestamp: 1.1
        )
        _ = recognizer.process(
            hands: [hand(thumbX: 0.95)], rows: rows, keyboardFrame: frame, screenFrame: frame, timestamp: 1.2
        )
        let second = recognizer.process(
            hands: [hand(thumbX: 0.76)], rows: rows, keyboardFrame: frame, screenFrame: frame, timestamp: 1.3
        )

        #expect(first.activatedKeyID == "a")
        #expect(first.state == .keyPressed)
        #expect(held.activatedKeyID == nil)
        #expect(second.activatedKeyID == "a")
    }

    @Test
    func keyboardTrackingLossClearsHoveredKeyAndPinchState() {
        var recognizer = AirKeyboardGestureRecognizer()
        recognizer.setActive(true)
        let rows = [[key("a"), key("b")]]
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        _ = recognizer.process(
            hands: [hand(thumbX: 0.76)], rows: rows, keyboardFrame: frame, screenFrame: frame, timestamp: 1
        )

        let lost = recognizer.process(
            hands: [], rows: rows, keyboardFrame: frame, screenFrame: frame, timestamp: 1.1
        )

        #expect(lost.state == .active)
        #expect(lost.hoveredKeyID == nil)
        #expect(lost.activatedKeyID == nil)
        #expect(!lost.isHandTracked)
    }

    @Test
    func keyCodeMappingCoversQwertyNumbersAndSymbols() {
        #expect(AirKeyboardKeyCode.code(for: "a")?.code == 0)
        #expect(AirKeyboardKeyCode.code(for: "q")?.code == 12)
        #expect(AirKeyboardKeyCode.code(for: "!")?.code == 18)
        #expect(AirKeyboardKeyCode.code(for: "!")?.requiresShift == true)
        #expect(AirKeyboardKeyCode.code(for: "한") == nil)
    }

    @Test
    func keyboardInputRequiresActiveModeAccessibilityAndNonSecureTarget() {
        #expect(AirKeyboardPermissionGate.allowsInput(isActive: true, isTrusted: true, isSecureFieldFocused: false))
        #expect(!AirKeyboardPermissionGate.allowsInput(isActive: false, isTrusted: true, isSecureFieldFocused: false))
        #expect(!AirKeyboardPermissionGate.allowsInput(isActive: true, isTrusted: false, isSecureFieldFocused: false))
        #expect(!AirKeyboardPermissionGate.allowsInput(isActive: true, isTrusted: true, isSecureFieldFocused: true))
    }

    private func key(_ label: String) -> AirKeyboardKey {
        AirKeyboardKey(id: label, label: label, action: .character(key: Character(label), shifted: false))
    }

    private func hand(thumbX: Double) -> [HandJoint] {
        [
            HandJoint(name: "wrist", normalizedX: 0.5, normalizedY: 0.1, confidence: 1),
            HandJoint(name: "indexMCP", normalizedX: 0.5, normalizedY: 0.3, confidence: 1),
            HandJoint(name: "indexTip", normalizedX: 0.75, normalizedY: 0.5, confidence: 0.9),
            HandJoint(name: "thumbTip", normalizedX: thumbX, normalizedY: 0.5, confidence: 1)
        ]
    }
}
