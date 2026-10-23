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
        // 언어 팩(앱에서 받은 것)과 같은 기본 모드로 번역한다.
        // iOS 26.4의 저지연(.lowLatency) 모드는 모델이 따로 필요할 수 있어, "설치됨"인데도
        // 번역이 실패(TranslationErrorDomain#1)하는 원인이 될 수 있어 쓰지 않는다.
        let session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)

        do {
            let translated = try await session.translate(text).targetText
            // 세션은 Sendable이 아니라 취소 핸들러에서 건드릴 수 없다. 결과를 받은 뒤 취소를 확인한다.
            try Task.checkCancellation()
            return translated
        } catch is CancellationError {
            throw CancellationError()
        } catch Translation.TranslationError.notInstalled {
            throw TranslationError.languagePackMissing
        } catch Translation.TranslationError.unsupportedLanguagePairing,
                Translation.TranslationError.unsupportedSourceLanguage,
                Translation.TranslationError.unsupportedTargetLanguage {
            throw TranslationError.unsupported
        } catch {
            throw TranslationError.failed(Self.describe(error))
        }
    }

    /// 프레임워크 오류를 "종류 (도메인#코드): 설명"으로 바꾼다.
    /// Apple 번역의 오류는 종류가 달라도 NSError 코드가 모두 1이라, 종류 이름을 따로 붙인다.
    /// 설명은 Apple이 주는 일반 문장이며 사용자 원문은 포함하지 않는다.
    static func describe(_ error: any Error) -> String {
        let kinds: [(String, Translation.TranslationError)] = [
            ("unsupportedSourceLanguage", .unsupportedSourceLanguage),
            ("unsupportedTargetLanguage", .unsupportedTargetLanguage),
            ("unsupportedLanguagePairing", .unsupportedLanguagePairing),
            ("unableToIdentifyLanguage", .unableToIdentifyLanguage),
            ("nothingToTranslate", .nothingToTranslate),
            ("alreadyCancelled", .alreadyCancelled),
            ("notInstalled", .notInstalled),
            ("internalError", .internalError)
        ]
        let kind = kinds.first { $0.1 ~= error }?.0 ?? "unknown"
        let nsError = error as NSError
        let reason = (error as? LocalizedError)?.failureReason
            ?? (error as? LocalizedError)?.errorDescription
            ?? nsError.localizedDescription
        return "\(kind) (\(nsError.domain)#\(nsError.code)): \(reason)"
    }
}
#endif
