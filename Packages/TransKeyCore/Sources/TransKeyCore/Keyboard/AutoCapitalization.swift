import Foundation

/// `UITextAutocapitalizationType`과 1:1 대응하는 플랫폼 독립 타입.
public enum AutoCapitalizationMode: Sendable {
    case none
    case words
    case sentences
    case allCharacters
}

public enum AutoCapitalization {
    private static let sentenceTerminators: Set<Character> = [".", "!", "?"]

    /// 커서 앞 문맥을 보고 다음 글자를 대문자로 시작해야 하는지 판단한다.
    /// - Parameter contextBefore: `documentContextBeforeInput`. nil이면 문서 시작으로 본다.
    public static func shouldCapitalize(mode: AutoCapitalizationMode, contextBefore: String?) -> Bool {
        let context = contextBefore ?? ""
        switch mode {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            guard let last = context.last else { return true }
            return last.isWhitespace || last.isNewline
        case .sentences:
            guard let last = context.last else { return true }
            if last.isNewline { return true }
            guard last.isWhitespace else { return false }
            let trimmed = context.trimmingCharacters(in: .whitespaces)
            guard let lastVisible = trimmed.last else { return true }
            return lastVisible.isNewline || sentenceTerminators.contains(lastVisible)
        }
    }
}
