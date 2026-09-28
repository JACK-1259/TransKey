import Foundation

/// TransKey가 다루는 언어. 원문 언어(ko, en)와 번역 대상 언어(en, ja, es, ko)를 모두 표현한다.
public enum Language: String, CaseIterable, Codable, Hashable, Sendable {
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
    case spanish = "es"

    /// BCP-47 언어 코드. `Locale.Language(identifier:)`에 그대로 넘길 수 있다.
    public var code: String { rawValue }

    /// 후보 바 칩에 표시하는 짧은 라벨.
    public var shortLabel: String { rawValue.uppercased() }

    public var flag: String {
        switch self {
        case .korean: "🇰🇷"
        case .english: "🇺🇸"
        case .japanese: "🇯🇵"
        case .spanish: "🇪🇸"
        }
    }

    /// 후보 바 칩 순서.
    public static let chipOrder: [Language] = [.english, .japanese, .spanish]

    /// 기본으로 켜져 있는 번역 대상 언어. 스페인어는 설정에서 켤 수 있다.
    public static let defaultTargets: [Language] = [.english, .japanese]
}
