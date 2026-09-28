import SwiftUI

/// 첫 실행 안내: 키보드 추가 → 전체 접근 → 언어 팩 → 체험.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case addKeyboard
        case fullAccess
        case languagePacks
        case tryIt
    }

    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @State private var step: Step = .addKeyboard
    @State private var languagePacks = LanguagePackViewModel(pairs: LanguagePackViewModel.essentialPairs)

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $step) {
                ForEach(Step.allCases, id: \.self) { step in
                    ScrollView {
                        page(for: step)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    }
                    .tag(step)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .background(Color(.systemGroupedBackground))
        .languagePackDownloads(languagePacks)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            StepIndicator(current: step.rawValue, total: Step.allCases.count)
            Spacer()
            if step != .tryIt {
                Button("건너뛰기") { finish() }
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .frame(minHeight: 44)
    }

    private var footer: some View {
        Button {
            if let next = Step(rawValue: step.rawValue + 1) {
                withAnimation { step = next }
            } else {
                finish()
            }
        } label: {
            Text(step == .tryIt ? "시작하기" : "다음")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func finish() {
        appState.onboardingCompleted = true
    }

    // MARK: - Pages

    @ViewBuilder
    private func page(for step: Step) -> some View {
        switch step {
        case .addKeyboard:
            OnboardingPage(
                title: "TransKey 키보드를 추가해요",
                message: "설정을 열고 키보드 › TransKey를 켜 주세요. 켠 다음 이 앱으로 돌아오면 돼요."
            ) {
                AddKeyboardIllustration()
            } extra: {
                settingsButton
                statusCard
            }
        case .fullAccess:
            OnboardingPage(
                title: "'전체 접근 허용'을 켜면 복사까지 돼요",
                message: "같은 화면에서 전체 접근 허용을 켜면, 번역을 누를 때 클립보드에도 복사돼요. 켜지 않아도 키보드는 쓸 수 있어요."
            ) {
                FullAccessIllustration()
            } extra: {
                settingsButton
                VStack(alignment: .leading, spacing: 12) {
                    Text("어떤 데이터가 쓰이나요?").font(.headline)
                    PrivacySummary()
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            }
        case .languagePacks:
            OnboardingPage(
                title: "번역 언어 팩을 받아요",
                message: "번역은 인터넷 없이 기기 안에서 돼요. 그러려면 언어 팩이 필요한데, 키보드는 직접 받을 수 없어서 여기서 미리 받아 둬요."
            ) {
                LanguagePackIllustration()
            } extra: {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 14) {
                        LanguagePackRows(model: languagePacks)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                    if let error = languagePacks.lastError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
        case .tryIt:
            OnboardingPage(
                title: "직접 써 봐요",
                message: "아래 칸을 누르고 🌐 키로 TransKey로 바꾼 뒤 '사과'를 입력해 보세요. 키보드 위에 번역이 떠요. 누르면 바로 입력돼요."
            ) {
                CandidateBarIllustration()
            } extra: {
                TestInputField()
            }
        }
    }

    private var settingsButton: some View {
        Button {
            appState.openSystemSettings(using: openURL)
        } label: {
            Label("설정 열기", systemImage: "gear")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    private var statusCard: some View {
        KeyboardStatusView()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}

private struct OnboardingPage<Illustration: View, Extra: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder let illustration: Illustration
    @ViewBuilder let extra: Extra

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            illustration
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            extra
        }
    }
}

private struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("\(total)단계 중 \(current + 1)단계")
    }
}
