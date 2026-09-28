import SwiftUI

/// 온보딩 일러스트. 실제 스크린샷으로 교체하기 전까지 설정 화면을 흉내 낸 그림을 보여준다.
struct IllustrationCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Color.accentColor.opacity(0.18), Color.cyan.opacity(0.12)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 24)
            )
            .accessibilityHidden(true)
    }
}

/// 설정 앱의 한 줄을 흉내 낸 행.
struct MockSettingsRow: View {
    let title: String
    var icon: String?
    var toggle: Bool?
    var chevron = false
    var highlighted = false

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor, in: .rect(cornerRadius: 6))
            }
            Text(title).font(.subheadline)
            Spacer()
            if let toggle {
                Capsule()
                    .fill(toggle ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 42, height: 26)
                    .overlay(alignment: toggle ? .trailing : .leading) {
                        Circle().fill(.white).padding(2)
                    }
            }
            if chevron {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(highlighted ? Color.accentColor.opacity(0.15) : .clear, in: .rect(cornerRadius: 8))
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }
}

struct MockSettingsPanel<Content: View>: View {
    let header: String
    @ViewBuilder let rows: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.leading, 12)
            VStack(spacing: 2) { rows }
                .padding(4)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        }
    }
}

struct AddKeyboardIllustration: View {
    var body: some View {
        IllustrationCard {
            MockSettingsPanel(header: "설정 › TransKey") {
                MockSettingsRow(title: "키보드", icon: "keyboard", chevron: true, highlighted: true)
                MockSettingsRow(title: "Siri 및 검색", icon: "magnifyingglass", chevron: true)
            }
        }
    }
}

struct FullAccessIllustration: View {
    var body: some View {
        IllustrationCard {
            MockSettingsPanel(header: "설정 › TransKey › 키보드") {
                MockSettingsRow(title: "TransKey", toggle: true)
                MockSettingsRow(title: "전체 접근 허용", toggle: true, highlighted: true)
            }
        }
    }
}

struct LanguagePackIllustration: View {
    var body: some View {
        IllustrationCard {
            HStack(spacing: 14) {
                Text("한국어").font(.headline)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("🇺🇸 English")
                    Text("🇯🇵 日本語")
                }
                .font(.headline)
                Spacer(minLength: 0)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.tint)
            }
            .padding(.vertical, 18)
        }
    }
}

/// 후보 바 미리보기: "사과" → apple / りんご
struct CandidateBarIllustration: View {
    var body: some View {
        IllustrationCard {
            VStack(spacing: 10) {
                HStack {
                    Text("사과").font(.title3)
                    Rectangle().fill(Color.accentColor).frame(width: 2, height: 22)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))

                HStack(spacing: 0) {
                    MockChip(flag: "🇺🇸", code: "EN", text: "apple", highlighted: true)
                    Divider().frame(height: 28)
                    MockChip(flag: "🇯🇵", code: "JA", text: "りんご", highlighted: false)
                }
                .padding(4)
                .background(Color(.systemGray5), in: .rect(cornerRadius: 12))
            }
        }
    }
}

private struct MockChip: View {
    let flag: String
    let code: String
    let text: String
    let highlighted: Bool

    var body: some View {
        VStack(spacing: 1) {
            Text("\(flag) \(code)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(text).font(.body)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(highlighted ? Color(.systemBackground) : .clear, in: .rect(cornerRadius: 8))
    }
}
