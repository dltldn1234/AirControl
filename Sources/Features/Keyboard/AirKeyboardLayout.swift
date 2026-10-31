import Foundation

enum AirKeyboardLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case korean = "한국어"

    var id: String { rawValue }
}

enum AirKeyboardAction: Hashable {
    case character(key: Character, shifted: Bool)
    case space
    case enter
    case backspace
    case shift
    case capsLock
    case inputSourceToggle
}

struct AirKeyboardKey: Identifiable, Hashable {
    let id: String
    let label: String
    let action: AirKeyboardAction
}

enum AirKeyboardLayout {
    static func rows(for language: AirKeyboardLanguage) -> [[AirKeyboardKey]] {
        let digits = Array("1234567890")
        let firstRow = Array(language == .english ? "qwertyuiop" : "ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ")
        let secondRow = Array(language == .english ? "asdfghjkl;" : "ㅁㄴㅇㄹㅎㅗㅓㅏㅣㅔ")
        let thirdRow = Array(language == .english ? "zxcvbnm,./" : "ㅋㅌㅊㅍㅠㅜㅡ,./")
        let physicalFirst = Array("qwertyuiop")
        let physicalSecond = Array("asdfghjkl;")
        let physicalThird = Array("zxcvbnm,./")

        return [
            digits.map { key($0, shifted: false) } + [special("⌫", id: "backspace", action: .backspace)],
            zip(firstRow, physicalFirst).map { label, physical in
                characterKey(label: label, physical: physical)
            },
            [special("⇧", id: "shift-left", action: .shift)] + zip(secondRow, physicalSecond).map { label, physical in
                characterKey(label: label, physical: physical)
            } + [special("⏎", id: "enter", action: .enter)],
            [special("⇧", id: "shift-right", action: .shift)] + zip(thirdRow, physicalThird).map { label, physical in
                characterKey(label: label, physical: physical)
            } + [special("한/영", id: "input-source", action: .inputSourceToggle)],
            [
                special("⇪", id: "caps-lock", action: .capsLock),
                special("한/영", id: "input-source-bottom", action: .inputSourceToggle),
                special("Space", id: "space", action: .space),
                special("⏎", id: "enter-bottom", action: .enter)
            ]
        ]
    }

    private static func characterKey(label: Character, physical: Character) -> AirKeyboardKey {
        AirKeyboardKey(id: "key-\(physical)", label: String(label), action: .character(key: physical, shifted: false))
    }

    private static func key(_ character: Character, shifted: Bool) -> AirKeyboardKey {
        AirKeyboardKey(
            id: "key-\(character)-\(shifted)",
            label: String(character),
            action: .character(key: character, shifted: shifted)
        )
    }

    private static func special(_ label: String, id: String, action: AirKeyboardAction) -> AirKeyboardKey {
        AirKeyboardKey(id: id, label: label, action: action)
    }
}
