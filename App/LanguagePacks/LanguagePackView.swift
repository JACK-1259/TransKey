import Observation
import SwiftUI
import TransKeyCore
import Translation

/// 온디바이스 번역 언어 팩 상태를 관리한다.
@MainActor
@Observable
final class LanguagePackViewModel {
    struct Pair: Hashable, Identifiable, Sendable {
        let source: String
        let target: String
        var id: String { "\(source)-\(target)" }

        var title: String {
            let name = { (code: String) in Locale.current.localizedString(forIdentifier: code) ?? code }
            return "\(name(source)) → \(name(target))"
        }

        var targetLanguage: Language { Language(rawValue: target) }
    }

    enum PackStatus: Equatable {
        case checking
        case installed
        case downloadRequired
        case downloading
        case unsupported

        var label: LocalizedStringKey {
            switch self {
            case .checking: "확인 중"
            case .installed: "설치됨"
            case .downloadRequired: "받기 필요"
            case .downloading: "받는 중"
            case .unsupported: "이 기기에서 지원 안 함"
            }
        }
    }

    /// 한국어 → 영어/일본어가 핵심 경로라 먼저 보여준다.
    static let essentialPairs: [Pair] = [
        Pair(source: "ko", target: "en"),
        Pair(source: "ko", target: "ja")
    ]

    static let allPairs: [Pair] = essentialPairs + [
        Pair(source: "ko", target: "es"),
        Pair(source: "en", target: "ko"),
        Pair(source: "en", target: "ja"),
        Pair(source: "en", target: "es")
    ]

    private(set) var pairs: [Pair]
    private(set) var isLoadingLanguages = false
    private(set) var statuses: [Pair: PackStatus] = [:]
    private(set) var lastError: String?
    var configuration: TranslationSession.Configuration?
    private var downloadingPair: Pair?

    init(pairs: [Pair]) {
        self.pairs = pairs
    }

    func status(for pair: Pair) -> PackStatus {
        statuses[pair] ?? .checking
    }

    /// 한국어 → `language` 언어 팩 상태.
    func status(for language: Language) -> PackStatus {
        status(for: Pair(source: Language.korean.code, target: language.code))
    }

    func requestDownload(for language: Language) {
        requestDownload(for: Pair(source: Language.korean.code, target: language.code))
    }

    /// 기기의 Apple 번역이 지원하는 모든 언어를 "한국어 → 언어" 쌍으로 불러오고 상태를 확인한다.
    /// 다른 앱(번역 앱, 설정)에서 받은 언어 팩도 시스템 전체가 공유하므로 여기서 "설치됨"으로 보인다.
    func loadSupportedLanguages() async {
        isLoadingLanguages = true
        let languages = await Self.fetchSupportedLanguages()
        pairs = languages
            .filter { $0 != .korean }
            .map { Pair(source: Language.korean.code, target: $0.code) }
        await refresh()
        isLoadingLanguages = false
    }

    var allInstalled: Bool {
        pairs.allSatisfy { status(for: $0) == .installed }
    }

    func requestDownload(for pair: Pair) {
        lastError = nil
        downloadingPair = pair
        statuses[pair] = .downloading
        var config = TranslationSession.Configuration(
            source: Locale.Language(identifier: pair.source),
            target: Locale.Language(identifier: pair.target)
        )
        // 같은 쌍을 다시 누른 경우에도 작업이 다시 실행되도록 무효화한다.
        if configuration == config { config.invalidate() }
        configuration = config
    }

    func refresh() async {
        for pair in pairs {
            statuses[pair] = await Self.fetchStatus(for: pair)
        }
    }

    func finishPreparation(error: String?) async {
        lastError = error
        downloadingPair = nil
        await refresh()
    }

    @concurrent
    private static func fetchSupportedLanguages() async -> [Language] {
        var seen = Set<Language>()
        // 같은 언어의 지역 변형(en, en-GB)은 하나로 합친다. 단, 중국어 간체/번체처럼 문자가 다른 경우는 따로 둔다.
        let languages = await LanguageAvailability().supportedLanguages
            .map { language -> Language in
                let base = Language(language)
                if base.code.hasPrefix("en") { return .english }
                return base
            }
            .filter { seen.insert($0).inserted }
        let list = languages.isEmpty ? Language.knownTranslationLanguages : languages
        return list.sorted(by: Language.displayOrder)
    }

    @concurrent
    private static func fetchStatus(for pair: Pair) async -> PackStatus {
        #if targetEnvironment(simulator)
        // 시뮬레이터에서는 Apple 번역이 동작하지 않는다. 키보드의 데모 사전이 있는 언어만 "설치됨"으로 본다.
        let demoLanguages = ["en", "ja", "es"]
        if pair.source == Language.korean.code {
            return demoLanguages.contains(pair.target) ? .installed : .unsupported
        }
        #endif
        let status = await LanguageAvailability().status(
            from: Locale.Language(identifier: pair.source),
            to: Locale.Language(identifier: pair.target)
        )
        switch status {
        case .installed: return .installed
        case .supported: return .downloadRequired
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }
}

/// 언어 쌍 목록 행. 온보딩과 언어 팩 탭에서 함께 쓴다.
struct LanguagePackRows: View {
    let model: LanguagePackViewModel

    var body: some View {
        ForEach(model.pairs) { pair in
            let status = model.status(for: pair)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pair.title)
                    Text(status.label)
                        .font(.caption)
                        .foregroundStyle(status == .installed ? .green : .secondary)
                }
                Spacer()
                switch status {
                case .installed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("설치됨")
                case .downloading, .checking:
                    ProgressView()
                case .downloadRequired:
                    Button("받기") { model.requestDownload(for: pair) }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                case .unsupported:
                    EmptyView()
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

extension View {
    /// 언어 팩 다운로드 요청을 처리한다. 시스템이 다운로드 확인 시트를 띄운다.
    func languagePackDownloads(_ model: LanguagePackViewModel) -> some View {
        self
            .task { await model.refresh() }
            .translationTask(model.configuration) { @concurrent [model] session in
                // 세션은 비격리 컨텍스트 안에서만 다룬다(Swift 6 데이터 레이스 방지).
                var message: String?
                do {
                    try await session.prepareTranslation()
                } catch {
                    message = error.localizedDescription
                }
                await model.finishPreparation(error: message)
            }
    }
}
