import Observation
import SwiftUI
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
            let name = { (code: String) in Locale.current.localizedString(forLanguageCode: code) ?? code }
            return "\(name(source)) → \(name(target))"
        }
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

    let pairs: [Pair]
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
    private static func fetchStatus(for pair: Pair) async -> PackStatus {
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

/// 언어 팩 탭.
struct LanguagePackView: View {
    @State private var model = LanguagePackViewModel(pairs: LanguagePackViewModel.allPairs)

    var body: some View {
        List {
            Section {
                LanguagePackRows(model: model)
            } header: {
                Text("번역 언어 팩")
            } footer: {
                Text("키보드는 언어 팩을 직접 받을 수 없어서, 여기서 미리 받아 둬야 해요. 받아 두면 인터넷 없이도 번역돼요.")
            }
            if let error = model.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("언어 팩")
        .languagePackDownloads(model)
        .refreshable { await model.refresh() }
    }
}
