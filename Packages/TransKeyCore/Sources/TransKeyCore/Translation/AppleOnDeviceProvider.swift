#if canImport(Translation)
import Foundation
import Translation

/// Apple Translation 프레임워크를 이용한 온디바이스 번역.
///
/// 키보드 익스텐션은 언어 팩 다운로드 UI를 띄울 수 없으므로 `init(installedSource:target:)`
/// 세션만 사용한다. 언어 팩이 없으면 `.languagePackMissing`을 던지고, 다운로드는 컨테이너 앱이 맡는다.
public struct AppleOnDeviceProvider: TranslationProvider {
    public init() {}

    public func translate(_ text: String, from source: Language?, to targets: [Language]) async throws -> [Language: String] {
        guard let source else { throw TranslationError.unsupported }
        guard !text.isEmpty else { throw TranslationError.emptyInput }

        var results: [Language: String] = [:]
        var lastError = TranslationError.unsupported
        for target in targets where target != source {
            try Task.checkCancellation()
            do {
                results[target] = try await Self.translate(text, from: source, to: target)
            } catch let error as TranslationError {
                lastError = error
            }
        }
        guard !results.isEmpty else { throw lastError }
        return results
    }

    public static func status(from source: Language, to target: Language) async -> LanguageAvailability.Status {
        await LanguageAvailability().status(
            from: Locale.Language(identifier: source.code),
            to: Locale.Language(identifier: target.code)
        )
    }

    /// 한 언어 쌍을 번역한다.
    /// 1) 언어 팩이 설치돼 있는지 확인 → 2) 세션 생성 → 3) 번역.
    private static func translate(_ text: String, from source: Language, to target: Language) async throws -> String {
        switch await status(from: source, to: target) {
        case .installed:
            break
        case .supported:
            throw TranslationError.languagePackMissing
        case .unsupported:
            throw TranslationError.unsupported
        @unknown default:
            throw TranslationError.unsupported
        }

        let sourceLanguage = Locale.Language(identifier: source.code)
        let targetLanguage = Locale.Language(identifier: target.code)
        let session: TranslationSession
        if #available(iOS 26.4, macOS 26.4, *) {
            session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage,
                                         preferredStrategy: .lowLatency)
        } else {
            session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
        }

        do {
            let translated = try await session.translate(text).targetText
            // 세션은 Sendable이 아니라 취소 핸들러에서 건드릴 수 없다. 결과를 받은 뒤 취소를 확인한다.
            try Task.checkCancellation()
            return translated
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // 에러 설명에 원문이 섞일 수 있으므로 타입 이름만 남긴다.
            throw TranslationError.failed(String(describing: type(of: error)))
        }
    }
}
#endif
