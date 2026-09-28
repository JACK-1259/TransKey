import XCTest
@testable import TransKeyCore

/// 원문별 지연과 결과를 지정할 수 있는 테스트용 번역 엔진.
private final class MockProvider: TranslationProvider, @unchecked Sendable {
    typealias Handler = @Sendable (String, Language, Int) async throws -> String

    private let lock = NSLock()
    private var _calls = 0
    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    var calls: Int { lock.withLock { _calls } }

    func translate(_ text: String, from source: Language?, to targets: [Language]) async throws -> [Language: String] {
        let attempt = lock.withLock { () -> Int in
            _calls += 1
            return _calls
        }
        var result: [Language: String] = [:]
        for target in targets {
            result[target] = try await handler(text, target, attempt)
        }
        return result
    }
}

@MainActor
final class TranslationCoordinatorTests: XCTestCase {
    private func source(_ text: String) -> SourceText {
        SourceText(text: text, deleteCount: text.count, trailingWhitespace: "", language: .korean)
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    private func chipStates(_ coordinator: TranslationCoordinator) -> [TranslationCoordinator.ChipState] {
        guard case .active(_, let chips) = coordinator.state else { return [] }
        return chips.map(\.state)
    }

    private func sourceText(_ coordinator: TranslationCoordinator) -> String? {
        guard case .active(let source, _) = coordinator.state else { return nil }
        return source.text
    }

    func testShowsLoadingThenResults() async {
        let provider = MockProvider { text, target, _ in "\(text)-\(target.code)" }
        let coordinator = TranslationCoordinator(provider: provider, debounce: .milliseconds(10))
        coordinator.update(source: source("사과"), targets: [.english, .japanese])
        XCTAssertEqual(chipStates(coordinator), [.loading, .loading])
        await waitUntil { chipStates(coordinator) == [.success("사과-en"), .success("사과-ja")] }
        XCTAssertEqual(chipStates(coordinator), [.success("사과-en"), .success("사과-ja")])
    }

    func testDebounceCoalescesRapidInput() async {
        let provider = MockProvider { text, _, _ in text }
        let coordinator = TranslationCoordinator(provider: provider, debounce: .milliseconds(80))
        for word in ["ㅅ", "사", "삭", "사고", "사과"] {
            coordinator.update(source: source(word), targets: [.english])
        }
        await waitUntil { chipStates(coordinator) == [.success("사과")] }
        XCTAssertEqual(provider.calls, 1)
    }

    func testStaleResponseDoesNotOverwriteNewer() async {
        let provider = MockProvider { text, _, _ in
            // 먼저 요청한 "사"가 더 늦게 끝난다.
            try await Task.sleep(for: .milliseconds(text == "사" ? 300 : 10))
            return text
        }
        let coordinator = TranslationCoordinator(provider: provider, debounce: .milliseconds(1))
        coordinator.update(source: source("사"), targets: [.english])
        try? await Task.sleep(for: .milliseconds(30))
        coordinator.update(source: source("사과"), targets: [.english])
        await waitUntil { chipStates(coordinator) == [.success("사과")] }
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sourceText(coordinator), "사과")
        XCTAssertEqual(chipStates(coordinator), [.success("사과")])
    }

    func testCacheHitIsImmediate() async {
        let provider = MockProvider { text, _, _ in text + "!" }
        let coordinator = TranslationCoordinator(provider: provider, debounce: .milliseconds(10))
        coordinator.update(source: source("사과"), targets: [.english])
        await waitUntil { chipStates(coordinator) == [.success("사과!")] }
        coordinator.clear()
        coordinator.update(source: source("사과"), targets: [.english])
        // 디바운스 없이 동기적으로 결과가 채워진다.
        XCTAssertEqual(chipStates(coordinator), [.success("사과!")])
        XCTAssertEqual(provider.calls, 1)
    }

    func testLanguagePackMissingIsNotRetried() async {
        let provider = MockProvider { _, _, _ in throw TranslationError.languagePackMissing }
        let coordinator = TranslationCoordinator(provider: provider, debounce: .milliseconds(1))
        coordinator.update(source: source("사과"), targets: [.english])
        await waitUntil { chipStates(coordinator) == [.failure(.languagePackMissing)] }
        XCTAssertEqual(chipStates(coordinator), [.failure(.languagePackMissing)])
        XCTAssertEqual(provider.calls, 1)
    }

    func testTransientFailureIsRetriedOnce() async {
        let provider = MockProvider { text, _, attempt in
            if attempt == 1 { throw TranslationError.failed("network") }
            return text
        }
        let coordinator = TranslationCoordinator(provider: provider, debounce: .milliseconds(1))
        coordinator.update(source: source("사과"), targets: [.english])
        await waitUntil { chipStates(coordinator) == [.success("사과")] }
        XCTAssertEqual(chipStates(coordinator), [.success("사과")])
        XCTAssertEqual(provider.calls, 2)
    }

    func testTimeout() async {
        let provider = MockProvider { text, _, _ in
            try await Task.sleep(for: .seconds(2))
            return text
        }
        let coordinator = TranslationCoordinator(provider: provider, debounce: .milliseconds(1),
                                                 timeout: .milliseconds(50), maxAttempts: 1)
        coordinator.update(source: source("사과"), targets: [.english])
        await waitUntil { chipStates(coordinator) == [.failure(.timeout)] }
        XCTAssertEqual(chipStates(coordinator), [.failure(.timeout)])
    }

    func testRetryRequestsFailedChipsAgain() async {
        let provider = MockProvider { text, _, attempt in
            if attempt <= 2 { throw TranslationError.failed("x") }
            return text
        }
        let coordinator = TranslationCoordinator(provider: provider, debounce: .milliseconds(1))
        coordinator.update(source: source("사과"), targets: [.english])
        await waitUntil { chipStates(coordinator) == [.failure(.failed("x"))] }
        coordinator.retry()
        await waitUntil { chipStates(coordinator) == [.success("사과")] }
        XCTAssertEqual(chipStates(coordinator), [.success("사과")])
    }

    func testNilSourceClearsBar() {
        let provider = MockProvider { text, _, _ in text }
        let coordinator = TranslationCoordinator(provider: provider)
        coordinator.update(source: source("사과"), targets: [.english])
        coordinator.update(source: nil, targets: [.english])
        XCTAssertEqual(coordinator.state, .empty)
    }

    func testSameSourceKeepsInFlightRequest() async {
        let provider = MockProvider { text, _, _ in text }
        let coordinator = TranslationCoordinator(provider: provider, debounce: .milliseconds(20))
        coordinator.update(source: source("사과"), targets: [.english])
        coordinator.update(source: SourceText(text: "사과", deleteCount: 3, trailingWhitespace: " ",
                                              language: .korean), targets: [.english])
        await waitUntil { chipStates(coordinator) == [.success("사과")] }
        XCTAssertEqual(provider.calls, 1)
        guard case .active(let current, _) = coordinator.state else { return XCTFail("expected active") }
        XCTAssertEqual(current.deleteCount, 3)
    }

    func testFallbackProviderUsesSecondaryForMissing() async throws {
        let primary = MockProvider { _, target, _ in
            if target == .japanese { throw TranslationError.languagePackMissing }
            return "p"
        }
        let secondary = MockProvider { _, _, _ in "s" }
        let fallback = FallbackTranslationProvider(primary: primary, secondary: secondary)
        let result = try await fallback.translate("사과", from: .korean, to: [.english])
        XCTAssertEqual(result, [.english: "p"])
        let jaResult = try await fallback.translate("사과", from: .korean, to: [.japanese])
        XCTAssertEqual(jaResult, [.japanese: "s"])
    }
}
