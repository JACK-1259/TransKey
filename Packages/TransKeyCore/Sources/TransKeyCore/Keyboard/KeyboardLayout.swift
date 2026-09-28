import Foundation

/// 문자 자판 언어.
public enum InputLanguage: String, Hashable, Sendable {
    case korean
    case english

    public var toggled: InputLanguage { self == .korean ? .english : .korean }
}

/// 자판 페이지.
public enum KeyboardPage: Hashable, Sendable {
    case letters
    case numbers
    case symbols
}

/// 키를 눌렀을 때 수행할 동작.
public enum KeyAction: Hashable, Sendable {
    /// 문자 입력. 값은 소문자(기본형) 기준이며 Shift 상태에 따라 대문자로 변환된다.
    case character(String)
    case shift
    case backspace
    case space
    case returnKey
    /// 시스템 입력 모드 전환(지구본). `handleInputModeList(from:with:)`로 연결된다.
    case globe
    case page(KeyboardPage)
    /// 한/영 전환. Phase 4에서 한국어 자판과 함께 활성화된다.
    case languageToggle
}

/// 키 폭. `units(1)`은 10열 기준 표준 문자 키 한 칸이다.
public enum KeyWidth: Hashable, Sendable {
    case units(Double)
    /// 행의 남은 공간을 채운다(스페이스 바).
    case flexible

    public static let standard = KeyWidth.units(1)
}

public struct Key: Hashable, Sendable {
    public let action: KeyAction
    public let width: KeyWidth
    /// Shift 상태에서 입력할 문자. nil이면 대문자 변환을 쓴다(두벌식 쌍자음 등에 사용).
    public let shifted: String?

    public init(_ action: KeyAction, width: KeyWidth = .standard, shifted: String? = nil) {
        self.action = action
        self.width = width
        self.shifted = shifted
    }

    public var isCharacter: Bool {
        if case .character = action { return true }
        return false
    }

    /// 문자 키가 실제로 입력할 텍스트. 문자 키가 아니면 nil.
    public func insertedText(uppercased: Bool) -> String? {
        guard case .character(let value) = action else { return nil }
        guard uppercased else { return value }
        return shifted ?? value.uppercased()
    }
}

/// 행 내부 키 배치 방식.
public enum RowAlignment: Hashable, Sendable {
    /// 전체 키 묶음을 가운데 정렬(QWERTY 2행처럼 좌우 여백이 생기는 행).
    case center
    /// 첫 키와 마지막 키를 양 끝에 붙이고 나머지를 가운데 정렬(Shift ... Backspace 행).
    case spread
}

public struct KeyboardRow: Hashable, Sendable {
    public let keys: [Key]
    public let alignment: RowAlignment

    public init(_ keys: [Key], alignment: RowAlignment = .center) {
        self.keys = keys
        self.alignment = alignment
    }
}

public struct KeyboardLayout: Hashable, Sendable {
    public let page: KeyboardPage
    public let rows: [KeyboardRow]

    public init(page: KeyboardPage, rows: [KeyboardRow]) {
        self.page = page
        self.rows = rows
    }

    /// 입력 언어와 페이지에 맞는 자판을 만든다. 숫자/기호 페이지는 언어와 무관하다.
    public static func make(language: InputLanguage, page: KeyboardPage, showsGlobe: Bool) -> KeyboardLayout {
        guard page == .letters, language == .korean else {
            return english(page: page, showsGlobe: showsGlobe)
        }
        return korean(showsGlobe: showsGlobe)
    }

    /// 두벌식 자판. Shift 시 ㅂㅈㄷㄱㅅ → ㅃㅉㄸㄲㅆ, ㅐㅔ → ㅒㅖ.
    public static func korean(showsGlobe: Bool) -> KeyboardLayout {
        let shiftedPairs: [String: String] = [
            "ㅂ": "ㅃ", "ㅈ": "ㅉ", "ㄷ": "ㄸ", "ㄱ": "ㄲ", "ㅅ": "ㅆ", "ㅐ": "ㅒ", "ㅔ": "ㅖ"
        ]
        func jamoKeys(_ string: String) -> [Key] {
            string.map { char in
                let value = String(char)
                return Key(.character(value), shifted: shiftedPairs[value] ?? value)
            }
        }
        return KeyboardLayout(page: .letters, rows: [
            KeyboardRow(jamoKeys("ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ")),
            KeyboardRow(jamoKeys("ㅁㄴㅇㄹㅎㅗㅓㅏㅣ")),
            KeyboardRow(
                [Key(.shift, width: .units(1.3))]
                    + jamoKeys("ㅋㅌㅊㅍㅠㅜㅡ")
                    + [Key(.backspace, width: .units(1.3))],
                alignment: .spread
            ),
            bottomRow(pageKey: .numbers, showsGlobe: showsGlobe)
        ])
    }

    /// 영어 자판 페이지를 만든다.
    /// - Parameter showsGlobe: 호스트가 `needsInputModeSwitchKey == true`일 때만 지구본 키를 넣는다.
    ///   (홈 버튼 없는 기기는 시스템이 키보드 아래에 지구본을 따로 그린다.)
    public static func english(page: KeyboardPage, showsGlobe: Bool) -> KeyboardLayout {
        switch page {
        case .letters:
            return KeyboardLayout(page: page, rows: [
                characterRow("qwertyuiop"),
                characterRow("asdfghjkl"),
                KeyboardRow(
                    [Key(.shift, width: .units(1.3))]
                        + characters("zxcvbnm")
                        + [Key(.backspace, width: .units(1.3))],
                    alignment: .spread
                ),
                bottomRow(pageKey: .numbers, showsGlobe: showsGlobe)
            ])
        case .numbers:
            return KeyboardLayout(page: page, rows: [
                characterRow("1234567890"),
                KeyboardRow(characters(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""])),
                punctuationRow(switchTo: .symbols),
                bottomRow(pageKey: .letters, showsGlobe: showsGlobe)
            ])
        case .symbols:
            return KeyboardLayout(page: page, rows: [
                KeyboardRow(characters(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])),
                KeyboardRow(characters(["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"])),
                punctuationRow(switchTo: .numbers),
                bottomRow(pageKey: .letters, showsGlobe: showsGlobe)
            ])
        }
    }

    private static func characters(_ string: String) -> [Key] {
        characters(string.map(String.init))
    }

    private static func characters(_ values: [String]) -> [Key] {
        values.map { Key(.character($0)) }
    }

    private static func characterRow(_ string: String) -> KeyboardRow {
        KeyboardRow(characters(string))
    }

    private static func punctuationRow(switchTo page: KeyboardPage) -> KeyboardRow {
        KeyboardRow(
            [Key(.page(page), width: .units(1.3))]
                + [".", ",", "?", "!", "'"].map { Key(.character($0), width: .units(1.4)) }
                + [Key(.backspace, width: .units(1.3))],
            alignment: .spread
        )
    }

    private static func bottomRow(pageKey: KeyboardPage, showsGlobe: Bool) -> KeyboardRow {
        let sideWidth = showsGlobe ? 1.25 : 1.5
        var keys = [Key(.page(pageKey), width: .units(sideWidth))]
        if showsGlobe {
            keys.append(Key(.globe, width: .units(1.25)))
        }
        keys.append(Key(.languageToggle, width: .units(sideWidth)))
        keys.append(Key(.space, width: .flexible))
        keys.append(Key(.returnKey, width: .units(2.3)))
        return KeyboardRow(keys)
    }
}
