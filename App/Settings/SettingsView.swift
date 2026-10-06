import SwiftUI
import TransKeyCore

/// 설정 탭. 변경 즉시 App Group에 저장되고, 키보드는 다음에 뜰 때 반영한다.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showsCacheCleared = false
    @State private var showsOnboardingReset = false

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        TranslationLanguagesView()
                    } label: {
                        LabeledContent("번역 언어", value: enabledLanguagesSummary)
                    }
                } footer: {
                    Text("한국어를 입력하면 켜 둔 언어로 번역돼요. 언어 팩을 받은 언어 중 최대 \(Language.maxEnabledTargets)개까지 켤 수 있어요.")
                }

                Section {
                    Picker("번역할 범위", selection: $appState.settings.sourceScope) {
                        Text("마지막 단어").tag(SourceScope.lastWord)
                        Text("마지막 문장").tag(SourceScope.lastSentence)
                    }
                    Picker("번역을 누르면", selection: $appState.settings.tapAction) {
                        Text("원문을 바꾸기").tag(ChipTapAction.replace)
                        Text("원문 뒤에 붙이기").tag(ChipTapAction.append)
                    }
                    Toggle("넣은 뒤 자동 띄어쓰기", isOn: $appState.settings.autoSpaceAfterInsert)
                    Toggle("입력 언어 자동 감지", isOn: $appState.settings.autoDetectSourceLanguage)
                } header: {
                    Text("번역 동작")
                } footer: {
                    Text("자동 감지를 켜면 영어를 입력했을 때 한국어·일본어 번역을 보여줘요.")
                }

                Section("키보드") {
                    Toggle("햅틱 피드백", isOn: $appState.settings.hapticsEnabled)
                    Toggle("키 소리", isOn: $appState.settings.keySoundEnabled)
                    Toggle("시스템 다크 모드 따르기", isOn: $appState.settings.followsSystemAppearance)
                }

                Section {
                    NavigationLink("데이터와 개인정보") {
                        PrivacyInfoView()
                    }
                    Button("번역 캐시 삭제", role: .destructive) {
                        appState.clearTranslationCache()
                        showsCacheCleared = true
                    }
                } header: {
                    Text("데이터")
                } footer: {
                    Text("최근 번역 결과는 키보드 메모리에만 잠깐 보관돼요. 삭제하면 키보드를 다음에 열 때 비워져요.")
                }

                Section("정보") {
                    Button("처음 안내 다시 보기") {
                        showsOnboardingReset = true
                    }
                    LabeledContent("버전", value: appVersion)
                }
            }
            .navigationTitle("설정")
            .alert("캐시를 비웠어요", isPresented: $showsCacheCleared) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("키보드를 다음에 열 때 적용돼요.")
            }
            .confirmationDialog("처음 안내를 다시 볼까요?", isPresented: $showsOnboardingReset,
                                titleVisibility: .visible) {
                Button("다시 보기") { appState.onboardingCompleted = false }
            }
        }
    }

    /// "🇺🇸 🇯🇵 영어, 일본어" 형태의 요약.
    private var enabledLanguagesSummary: String {
        appState.settings.orderedTargets
            .map { "\($0.flag) \($0.displayName())" }
            .joined(separator: ", ")
    }
}
