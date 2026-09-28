import Foundation

/// 번역 대상 원문과, 교체 시 지워야 할 글자 수.
public struct SourceText: Equatable, Sendable {
    /// 번역할 텍스트(앞뒤 공백 제거, 최대 길이로 자름).
    public let text: String
    /// 커서에서 원문 시작까지의 글자(grapheme) 수. 원문 뒤 공백을 포함한다.
    public let deleteCount: Int
    /// 원문 뒤에 붙어 있던 공백. 교체 후 다시 붙인다.
    public let trailingWhitespace: String
    public let language: Language

    public init(text: String, deleteCount: Int, trailingWhitespace: String, language: Language) {
        self.text = text
        self.deleteCount = deleteCount
        self.trailingWhitespace = trailingWhitespace
        self.language = language
    }
}

public enum SourceLanguageDetector {
    /// 한글 음절이 있으면 한국어, 라틴 문자가 있으면 영어. 둘 다 없으면 nil(숫자, 기호, 미완성 자모만 있는 경우).
    public static func detect(_ text: String) -> Language? {
        var hasLatin = false
        for scalar in text.unicodeScalars {
            if (0xAC00...0xD7A3).contains(scalar.value) { return .korean }
            if ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar) { hasLatin = true }
        }
        return hasLatin ? .english : nil
    }
}

/// 커서 앞 텍스트(`documentContextBeforeInput`)에서 번역할 원문을 뽑는다.
///
/// 예) "나는 사과 " (끝에 공백)
///   - 뒤 공백 " "은 떼어 두고 → "나는 사과"
///   - 마지막 구분자(공백·문장부호) 뒤를 자르면 → "사과"
///   - 한글이 있으니 언어는 한국어
///   - 칩을 탭하면 지울 글자 수 = "사과"(2) + 공백(1) = 3
public enum SourceTextExtractor {
    public static let maxLength = 200

    private static let wordSeparators: Set<Character> = [
        ".", ",", "!", "?", ";", ":", "\"", "(", ")", "[", "]", "{", "}", "<", ">",
        "…", "·", "。", "、", "「", "」", "~", "/", "|", "\\"
    ]
    private static let sentenceTerminators: Set<Character> = [".", "!", "?", "。", "…"]

    /// - Parameter context: `documentContextBeforeInput`.
    public static func extract(from context: String?, scope: SourceScope) -> SourceText? {
        guard let context, !context.isEmpty else { return nil }

        // 원문 뒤의 공백(줄바꿈 제외)은 허용한다: "사과 " 뒤에서도 "사과"를 번역한다.
        let trailing = String(context.reversed().prefix { $0 == " " || $0 == "\t" }.reversed())
        let body = context.dropLast(trailing.count)
        guard let last = body.last, !last.isNewline else { return nil }

        let segment: Substring
        switch scope {
        case .lastWord:
            let start = body.lastIndex { $0.isWhitespace || $0.isNewline || wordSeparators.contains($0) }
            segment = start.map { body[body.index(after: $0)...] } ?? body[...]
        case .lastSentence:
            // 문장 끝 부호는 문장에 포함하되, 그 앞 문장과의 경계로 쓴다.
            let searchArea = sentenceTerminators.contains(last) ? body.dropLast() : body
            let start = searchArea.lastIndex { sentenceTerminators.contains($0) || $0.isNewline }
            segment = start.map { body[body.index(after: $0)...] } ?? body[...]
        }

        let leadingSpaces = segment.prefix { $0.isWhitespace }.count
        let core = segment.dropFirst(leadingSpaces)
        guard !core.isEmpty else { return nil }

        let text = String(core.suffix(maxLength))
        guard let language = SourceLanguageDetector.detect(text) else { return nil }
        return SourceText(
            text: text,
            deleteCount: core.count + trailing.count,
            trailingWhitespace: trailing,
            language: language
        )
    }
}
