import Foundation
import NaturalLanguage

/// 입력한 텍스트가 어느 언어인지 감지한다.
///
/// ## 감지 순서
/// 1. **문자 종류로 바로 정할 수 있는 언어**
///    - 한글 → 한국어, 히라가나·가타카나 → 일본어, 태국 문자 → 태국어,
///      아랍 문자 → 아랍어, 데바나가리 → 힌디어
///    - 한자만 있으면(가나 없음) → 중국어. 간체/번체는 NaturalLanguage로 구분한다.
/// 2. **여러 언어가 같은 문자를 쓰는 경우**(알파벳, 키릴 문자)
///    - Apple 번역이 지원하는 언어로 후보를 좁혀 NaturalLanguage로 판단한다.
///    - 한 단어처럼 짧으면 판단이 흔들리므로 영어에 가중치를 주고,
///      확신이 낮으면 영어(키릴 문자는 러시아어)로 본다.
/// 3. 숫자·기호·미완성 자모(ㅅ)만 있으면 nil → 번역하지 않는다.
///
/// NaturalLanguage는 iOS 기본 프레임워크라 앱 크기가 늘지 않는다.
public enum SourceLanguageDetector {
    /// 알파벳을 쓰는 언어 중 Apple 번역이 지원하는 언어.
    static let latinCandidates: [NLLanguage] = [
        .english, .spanish, .french, .german, .italian, .portuguese,
        .dutch, .polish, .turkish, .vietnamese, .indonesian
    ]
    static let cyrillicCandidates: [NLLanguage] = [.russian, .ukrainian]

    /// NaturalLanguage 판단을 믿을 최소 확률.
    /// 영어에 가중치를 준 상태에서 한 단어를 판단하면 확률이 낮게 나온다(예: "manzana" 스페인어 0.45).
    /// 실측해 보니 0.35면 manzana·hola·bonjour는 정확히 잡고, apple·hello·water는 영어로 유지됐다.
    /// "casa"처럼 여러 언어에 같은 단어가 있으면 확률이 낮아 영어로 처리된다.
    static let minimumConfidence = 0.35

    public static func detect(_ text: String) -> Language? {
        var hasKana = false, hasHan = false, hasLatin = false, hasCyrillic = false
        var hasThai = false, hasArabic = false, hasDevanagari = false

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0xAC00...0xD7A3: return .korean          // 한글 음절
            case 0x3040...0x30FF: hasKana = true           // 히라가나·가타카나
            case 0x4E00...0x9FFF, 0x3400...0x4DBF: hasHan = true // 한자
            case 0x0E00...0x0E7F: hasThai = true
            case 0x0600...0x06FF: hasArabic = true
            case 0x0900...0x097F: hasDevanagari = true
            case 0x0400...0x04FF: hasCyrillic = true
            case 0x41...0x5A, 0x61...0x7A, 0xC0...0x24F: hasLatin = true // 기본·확장 라틴(é, ñ, ü …)
            default: break
            }
        }

        if hasKana { return .japanese }
        if hasHan { return chineseVariant(of: text) }
        if hasThai { return Language("th") }
        if hasArabic { return Language("ar-AE") }
        if hasDevanagari { return Language("hi") }
        if hasCyrillic {
            return recognize(text, among: cyrillicCandidates, hints: [.russian: 0.6, .ukrainian: 0.4])
                ?? Language("ru")
        }
        if hasLatin {
            var hints: [NLLanguage: Double] = [:]
            for language in latinCandidates { hints[language] = 0.05 }
            hints[.english] = 0.5
            return recognize(text, among: latinCandidates, hints: hints) ?? .english
        }
        return nil
    }

    private static func chineseVariant(of text: String) -> Language {
        let recognized = recognize(text, among: [.simplifiedChinese, .traditionalChinese],
                                   hints: [.simplifiedChinese: 0.6, .traditionalChinese: 0.4])
        return recognized ?? Language("zh")
    }

    private static func recognize(_ text: String, among candidates: [NLLanguage],
                                  hints: [NLLanguage: Double]) -> Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = candidates
        recognizer.languageHints = hints
        recognizer.processString(text)
        guard let (language, probability) = recognizer.languageHypotheses(withMaximum: 1).first,
              probability >= minimumConfidence else { return nil }
        return translationLanguage(for: language)
    }

    /// NaturalLanguage 언어를 Apple 번역 식별자로 바꾼다(예: zh-Hant → zh-TW).
    static func translationLanguage(for language: NLLanguage) -> Language {
        switch language {
        case .simplifiedChinese: Language("zh")
        case .traditionalChinese: Language("zh-TW")
        case .arabic: Language("ar-AE")
        default: Language(rawValue: language.rawValue)
        }
    }
}
