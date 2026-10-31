import Testing
@testable import AirControl

struct AirKeyboardTests {
    @Test
    func englishAndKoreanLayoutsHaveExpectedRowsAndEditingKeys() {
        let english = AirKeyboardLayout.rows(for: .english)
        let korean = AirKeyboardLayout.rows(for: .korean)

        #expect(english.count == 5)
        #expect(english[1].map(\.label).joined() == "qwertyuiop")
        #expect(korean[1].map(\.label).joined() == "ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ")
        #expect(english.flatMap { $0 }.contains { $0.action == .space })
        #expect(english.flatMap { $0 }.contains { $0.action == .backspace })
        #expect(english.flatMap { $0 }.contains { $0.action == .inputSourceToggle })
    }
}
