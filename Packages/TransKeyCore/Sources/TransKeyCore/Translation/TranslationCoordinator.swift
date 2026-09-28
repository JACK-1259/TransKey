import Foundation

/// 후보 바의 번역 상태를 관리한다.
///
/// ## 동작 순서
/// 1. `update(source:targets:)` — 키 입력마다 호출된다.
///    - 원문이 이전과 같으면 아무것도 하지 않는다(진행 중인 번역 유지).
///    - 다르면 이전 작업을 취소하고 세대 번호(`generation`)를 1 올린다.
/// 2. 캐시 확인 — 이미 번역해 본 단어는 즉시 결과를 보여준다(디바운스 없음).
/// 3. 디바운스 — 캐시에 없으면 칩을 "로딩(점 3개)"으로 바꾸고 0.3초 기다린다.
///    그 사이 새 입력이 오면 1번에서 취소되므로, 빠르게 칠 때는 마지막 단어만 번역한다.
/// 4. 번역 — 대상 언어(EN, JA …)마다 동시에 요청한다. 3초 타임아웃, 실패하면 1번 재시도.
/// 5. 결과 반영 — 응답의 세대 번호가 현재와 다르면 버린다(늦게 온 옛 결과가 최신 결과를 덮지 않게).
///    같으면 칩 상태를 바꾸고 캐시에 저장한 뒤 `onChange`로 화면에 알린다.
///
/// - 입력이 멈추고 `debounce` 뒤에 요청한다. 새 입력이 오면 이전 요청은 취소한다.
/// - 요청마다 세대 번호를 붙여, 늦게 도착한 오래된 응답이 최신 상태를 덮어쓰지 못하게 한다.
/// - 캐시에 있으면 디바운스 없이 즉시 표시한다.
@MainActor
public final class TranslationCoordinator {
    public enum ChipState: Equatable, Sendable {
        case loading
        case success(String)
        case failure(TranslationError)
    }

    public struct Chip: Equatable, Sendable {
        public let language: Language
        public var state: ChipState
    }

    public enum BarState: Equatable, Sendable {
        case empty
        case active(source: SourceText, chips: [Chip])
    }

    public var onChange: ((BarState) -> Void)?
    public private(set) var state: BarState = .empty {
        didSet {
            if state != oldValue { onChange?(state) }
        }
    }

    private let provider: any TranslationProvider
    private let debounce: Duration
    private let timeout: Duration
    private let maxAttempts: Int
    private var cache: LRUCache<TranslationCacheKey, String>
    private var task: Task<Void, Never>?
    private var generation = 0

    public init(provider: any TranslationProvider,
                debounce: Duration = .milliseconds(300),
                timeout: Duration = .seconds(3),
                maxAttempts: Int = 2,
                cacheCapacity: Int = 200) {
        self.provider = provider
        self.debounce = debounce
        self.timeout = timeout
        self.maxAttempts = max(1, maxAttempts)
        self.cache = LRUCache(capacity: cacheCapacity)
    }

    /// 현재 원문으로 후보 바를 갱신한다. 원문과 대상 언어가 같으면 진행 중인 요청을 유지한다.
    public func update(source: SourceText?, targets: [Language]) {
        guard let source, !targets.isEmpty else {
            clear()
            return
        }
        if case .active(let current, let chips) = state,
           current.text == source.text, current.language == source.language,
           chips.map(\.language) == targets {
            // 같은 원문: 삭제 범위(뒤 공백 등)만 최신으로 바꾼다.
            state = .active(source: source, chips: chips)
            return
        }
        start(source: source, targets: targets)
    }

    /// 실패한 칩만 다시 요청한다.
    public func retry() {
        guard case .active(let source, let chips) = state else { return }
        let failed = chips.filter {
            if case .failure = $0.state { return true }
            return false
        }.map(\.language)
        guard !failed.isEmpty else { return }
        generation += 1
        let updated = chips.map { chip in
            failed.contains(chip.language) ? Chip(language: chip.language, state: .loading) : chip
        }
        state = .active(source: source, chips: updated)
        request(source: source, targets: failed, generation: generation, debounced: false)
    }

    public func clear() {
        task?.cancel()
        task = nil
        generation += 1
        state = .empty
    }

    public func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private

    private func start(source: SourceText, targets: [Language]) {
        task?.cancel()
        generation += 1

        var pending: [Language] = []
        let chips = targets.map { target -> Chip in
            let key = TranslationCacheKey(text: source.text, source: source.language, target: target)
            if let cached = cache.value(for: key) {
                return Chip(language: target, state: .success(cached))
            }
            pending.append(target)
            return Chip(language: target, state: .loading)
        }
        state = .active(source: source, chips: chips)
        guard !pending.isEmpty else {
            task = nil
            return
        }
        request(source: source, targets: pending, generation: generation, debounced: true)
    }

    private func request(source: SourceText, targets: [Language], generation: Int, debounced: Bool) {
        let provider = provider
        let timeout = timeout
        let maxAttempts = maxAttempts
        let text = source.text
        let sourceLanguage = source.language

        task = Task { [weak self] in
            if debounced {
                do {
                    try await Task.sleep(for: self?.debounce ?? .zero)
                } catch {
                    return
                }
            }
            await withTaskGroup(of: (Language, Result<String, TranslationError>).self) { group in
                for target in targets {
                    group.addTask {
                        let result = await Self.translate(text, from: sourceLanguage, to: target,
                                                          provider: provider, timeout: timeout,
                                                          maxAttempts: maxAttempts)
                        return (target, result)
                    }
                }
                for await (target, result) in group {
                    guard !Task.isCancelled else { return }
                    self?.apply(result, for: target, source: source, generation: generation)
                }
            }
        }
    }

    private nonisolated static func translate(
        _ text: String, from source: Language, to target: Language,
        provider: any TranslationProvider, timeout: Duration, maxAttempts: Int
    ) async -> Result<String, TranslationError> {
        var lastError = TranslationError.failed("unknown")
        for _ in 0..<maxAttempts {
            if Task.isCancelled { return .failure(.failed("cancelled")) }
            do {
                let result = try await Timeout.run(timeout) {
                    try await provider.translate(text, from: source, to: [target])
                }
                guard let value = result[target], !value.isEmpty else {
                    return .failure(.failed("empty"))
                }
                return .success(value)
            } catch let error as TranslationError {
                lastError = error
                // 언어 팩 미설치/미지원은 재시도해도 결과가 같다.
                if error == .languagePackMissing || error == .unsupported { break }
            } catch {
                lastError = .failed(String(describing: type(of: error)))
            }
        }
        return .failure(lastError)
    }

    private func apply(_ result: Result<String, TranslationError>, for target: Language,
                       source: SourceText, generation: Int) {
        // 오래된 요청의 응답은 버린다.
        guard generation == self.generation,
              case .active(let current, var chips) = state,
              let index = chips.firstIndex(where: { $0.language == target }) else { return }
        switch result {
        case .success(let value):
            chips[index].state = .success(value)
            cache.set(value, for: TranslationCacheKey(text: source.text, source: source.language, target: target))
        case .failure(let error):
            chips[index].state = .failure(error)
        }
        state = .active(source: current, chips: chips)
    }
}
