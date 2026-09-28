import Foundation

public enum TranslationError: Error, Equatable, Sendable {
    /// 온디바이스 언어 팩이 설치되지 않음(컨테이너 앱에서 받아야 함).
    case languagePackMissing
    /// 해당 언어 쌍을 지원하지 않음.
    case unsupported
    case emptyInput
    case timeout
    case offline
    /// 기타 실패. 사용자 원문은 담지 않는다.
    case failed(String)
}

/// 번역 엔진 추상화. 온디바이스, 클라우드, 폴백 구현을 교체할 수 있다.
///
/// 현재 구현체
/// - `AppleOnDeviceProvider`: Apple 온디바이스 번역(실기기)
/// - `FallbackTranslationProvider`: 첫 엔진이 실패하면 두 번째 엔진으로 넘김
/// - `SimulatorDemoProvider`: 시뮬레이터 전용 데모 사전(키보드 타깃)
public protocol TranslationProvider: Sendable {
    /// - Returns: 성공한 언어만 담긴 결과. 하나도 성공하지 못하면 throw한다.
    func translate(_ text: String, from source: Language?, to targets: [Language]) async throws -> [Language: String]
}

/// 첫 번째 엔진이 실패하면 두 번째 엔진으로 넘어간다(온디바이스 우선 / 클라우드 우선).
public struct FallbackTranslationProvider: TranslationProvider {
    private let primary: any TranslationProvider
    private let secondary: any TranslationProvider

    public init(primary: any TranslationProvider, secondary: any TranslationProvider) {
        self.primary = primary
        self.secondary = secondary
    }

    public func translate(_ text: String, from source: Language?, to targets: [Language]) async throws -> [Language: String] {
        do {
            let result = try await primary.translate(text, from: source, to: targets)
            let missing = targets.filter { result[$0] == nil }
            guard !missing.isEmpty else { return result }
            let rest = (try? await secondary.translate(text, from: source, to: missing)) ?? [:]
            return result.merging(rest) { first, _ in first }
        } catch {
            try Task.checkCancellation()
            return try await secondary.translate(text, from: source, to: targets)
        }
    }
}

public enum Timeout {
    /// `operation`이 `duration` 안에 끝나지 않으면 `TranslationError.timeout`을 던진다.
    public static func run<T: Sendable>(
        _ duration: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: duration)
                throw TranslationError.timeout
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw TranslationError.timeout }
            return first
        }
    }
}
