import Foundation

/// TransKey가 다루는 언어. BCP-47 식별자(예: "en", "ja", "zh-TW")를 그대로 감싼다.
///
/// 처음에는 ko/en/ja/es 4개짜리 enum이었지만, Apple 번역이 지원하는 모든 언어(약 20개)를
/// 쓸 수 있도록 문자열 기반 구조체로 바꿨다. 저장 형식은 그대로 문자열("en")이라 기존 설정과 호환된다.
public struct Language: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    /// 최소 형태의 BCP-47 식별자. `Locale.Language(identifier:)`에 그대로 넘길 수 있다.
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ code: String) {
        self.rawValue = code
    }

    /// Apple 번역이 돌려주는 언어를 TransKey 언어로 바꾼다(예: zh-Hans-CN → "zh").
    public init(_ language: Locale.Language) {
        self.rawValue = language.minimalIdentifier
    }

    public var id: String { rawValue }
    public var code: String { rawValue }

    public var localeLanguage: Locale.Language {
        Locale.Language(identifier: rawValue)
    }

    public static let korean = Language("ko")
    public static let english = Language("en")
    public static let japanese = Language("ja")
    public static let spanish = Language("es")

    // MARK: - 표시

    /// 후보 바 칩에 표시하는 짧은 라벨(언어 코드). 같은 언어의 지역 변형은 국기로 구분한다.
    public var shortLabel: String {
        (localeLanguage.languageCode?.identifier ?? rawValue).uppercased()
    }

    /// 언어의 대표 지역 국기. 지역을 알 수 없으면 🌐.
    /// 예) "ja" → ja-Jpan-JP → 🇯🇵, "zh-TW" → zh-Hant-TW → 🇹🇼
    public var flag: String {
        let maximal = Locale.Language(identifier: localeLanguage.maximalIdentifier)
        guard let region = maximal.region?.identifier, region.count == 2,
              region.unicodeScalars.allSatisfy({ ("A"..."Z").contains($0) }) else {
            return "🌐"
        }
        // 국기 이모지 = 지역 코드 두 글자를 각각 "지역 표시 문자"로 바꾼 것.
        return String(String.UnicodeScalarView(region.unicodeScalars.compactMap {
            Unicode.Scalar(0x1F1E6 + $0.value - 0x41)
        }))
    }

    /// 사용자 언어로 된 이름(예: 한국어 환경에서 "일본어", "중국어(대만)").
    public func displayName(in locale: Locale = .current) -> String {
        locale.localizedString(forIdentifier: rawValue) ?? rawValue
    }

    // MARK: - 목록

    /// 기본으로 켜져 있는 번역 대상 언어.
    public static let defaultTargets: [Language] = [.english, .japanese]

    /// 후보 바에 한 번에 보여줄 수 있는 최대 언어 수(iOS 자동완성 바와 같은 3칸).
    public static let maxEnabledTargets = 3

    /// Apple 번역이 지원하는 언어(iOS 27 기준). 실제 목록은 기기에서 `LanguageAvailability`로 받아오고,
    /// 받아올 수 없을 때(시뮬레이터 등)만 이 목록을 쓴다.
    public static let knownTranslationLanguages: [Language] = [
        "en", "ja", "zh", "zh-TW", "es", "fr", "de", "it", "pt", "ru",
        "vi", "th", "id", "tr", "pl", "nl", "uk", "ar-AE", "hi", "ko"
    ].map { Language(rawValue: $0) }

    /// 화면과 후보 바에서의 정렬 순서. 많이 쓰는 언어를 앞에, 나머지는 코드 순.
    public static func displayOrder(_ lhs: Language, _ rhs: Language) -> Bool {
        let order = knownTranslationLanguages
        switch (order.firstIndex(of: lhs), order.firstIndex(of: rhs)) {
        case let (l?, r?): return l < r
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Codable(문자열 하나로 저장)

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
