import SwiftUI
import TransKeyCore

/// 번역 언어 선택 화면.
///
/// ## 동작
/// 1. 기기의 Apple 번역이 지원하는 언어 전체(약 20개)를 불러와 "한국어 → 언어" 언어 팩 상태를 확인한다.
/// 2. 언어 팩이 설치된 언어는 토글로 켜고 끌 수 있다(최대 3개 → 키보드 위 번역 칩).
/// 3. 설치되지 않은 언어는 "받기"를 누르면 시스템 다운로드 창이 뜬다.
/// 4. 언어 팩은 아이폰 전체가 공유한다. 번역 앱이나 다른 앱에서 받은 뒤 돌아오면(scenePhase가 active)
///    상태를 다시 읽어 바로 켤 수 있게 된다.
struct TranslationLanguagesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = LanguagePackViewModel(pairs: [])
    @State private var showsLimitAlert = false

    /// 켤 수 있거나 이미 켜 둔 언어.
    private var availableLanguages: [Language] {
        model.pairs.map(\.targetLanguage).filter {
            model.status(for: $0) == .installed || appState.settings.enabledTargets.contains($0)
        }
    }

    /// 받으면 쓸 수 있는 언어.
    private var downloadableLanguages: [Language] {
        model.pairs.map(\.targetLanguage).filter {
            !availableLanguages.contains($0)
                && [.downloadRequired, .downloading].contains(model.status(for: $0))
        }
    }

    var body: some View {
        List {
            Section {
                if availableLanguages.isEmpty, !model.isLoadingLanguages {
                    Text("아직 받은 언어 팩이 없어요. 아래에서 받아 주세요.")
                        .foregroundStyle(.secondary)
                }
                ForEach(availableLanguages) { language in
                    LanguageRow(language: language, status: model.status(for: language)) {
                        toggleControl(for: language)
                    }
                }
            } header: {
                HStack {
                    Text("사용할 수 있는 언어")
                    Spacer()
                    Text("\(appState.settings.enabledTargets.count)/\(Language.maxEnabledTargets)")
                        .monospacedDigit()
                }
            } footer: {
                Text("최대 \(Language.maxEnabledTargets)개까지 켤 수 있어요. 켠 언어가 키보드 위 번역 칩으로 나타나요.")
            }

            Section {
                if model.isLoadingLanguages {
                    HStack {
                        ProgressView()
                        Text("지원 언어를 확인하는 중…").foregroundStyle(.secondary)
                    }
                }
                ForEach(downloadableLanguages) { language in
                    LanguageRow(language: language, status: model.status(for: language)) {
                        downloadControl(for: language)
                    }
                }
            } header: {
                Text("받을 수 있는 언어")
            } footer: {
                #if targetEnvironment(simulator)
                Text("시뮬레이터에서는 Apple 번역이 동작하지 않아 데모용 영어·일본어·스페인어만 보여요.")
                #else
                Text("아이폰의 번역 앱이나 다른 앱에서 받은 언어 팩도 자동으로 인식돼요. 받고 돌아오면 위 목록에 나타나요.")
                #endif
            }

            if let error = model.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("번역 언어")
        .task { await model.loadSupportedLanguages() }
        .languagePackDownloads(model)
        .refreshable { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            // 번역 앱이나 설정에서 언어 팩을 받고 돌아왔을 수 있으니 다시 확인한다.
            if phase == .active {
                Task { await model.refresh() }
            }
        }
        .alert("최대 \(Language.maxEnabledTargets)개까지 켤 수 있어요", isPresented: $showsLimitAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("키보드 위 번역 칩은 \(Language.maxEnabledTargets)칸이에요. 다른 언어를 끄고 다시 켜 주세요.")
        }
    }

    @ViewBuilder
    private func toggleControl(for language: Language) -> some View {
        let isOn = appState.settings.enabledTargets.contains(language)
        HStack(spacing: 8) {
            // 켜 둔 언어의 언어 팩이 지워졌다면 다시 받을 수 있게 한다.
            if model.status(for: language) == .downloadRequired {
                Button("받기") { model.requestDownload(for: language) }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    if !appState.setTarget(language, enabled: newValue) {
                        showsLimitAlert = newValue
                    }
                }
            ))
            .labelsHidden()
            .accessibilityLabel(language.displayName())
        }
    }

    @ViewBuilder
    private func downloadControl(for language: Language) -> some View {
        if model.status(for: language) == .downloading {
            ProgressView()
        } else {
            Button("받기") { model.requestDownload(for: language) }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
    }
}

/// 국기 + 언어 이름 + 상태 한 줄.
private struct LanguageRow<Control: View>: View {
    let language: Language
    let status: LanguagePackViewModel.PackStatus
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 12) {
            Text(language.flag)
                .font(.title2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(language.displayName())
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(status == .installed ? Color.green : Color.secondary)
            }
            Spacer()
            control
        }
    }

    private var statusText: LocalizedStringKey {
        status == .downloadRequired ? "언어 팩이 없어요" : status.label
    }
}
