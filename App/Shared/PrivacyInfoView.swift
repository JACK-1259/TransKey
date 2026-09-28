import SwiftUI

/// 어떤 데이터가 전송/저장되는지 안내. 온보딩과 설정에서 함께 쓴다.
struct PrivacySummary: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PrivacyItem(
                icon: "iphone",
                title: "번역은 이 기기 안에서 해요",
                message: "Apple의 온디바이스 번역을 써요. 입력한 글자는 TransKey 서버나 다른 곳으로 보내지 않아요."
            )
            PrivacyItem(
                icon: "doc.on.clipboard",
                title: "전체 접근은 복사에만 써요",
                message: "번역 결과를 클립보드에 복사하려면 iOS 규칙상 '전체 접근 허용'이 필요해요. 꺼져 있으면 클립보드 복사만 되지 않아요."
            )
            PrivacyItem(
                icon: "tray",
                title: "입력한 내용은 저장하지 않아요",
                message: "저장하는 건 설정값뿐이에요. 번역 결과는 키보드가 켜져 있는 동안만 메모리에 잠깐 기억했다가 사라져요."
            )
            PrivacyItem(
                icon: "lock",
                title: "비밀번호 입력 중에는 꺼져요",
                message: "비밀번호 칸에서는 번역 바가 사라지고 아무것도 처리하지 않아요."
            )
        }
    }
}

private struct PrivacyItem: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct PrivacyInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("TransKey는 입력한 내용을 번역하는 데에만 쓰고, 저장하거나 밖으로 보내지 않아요.")
                    .font(.body)
                PrivacySummary()
                Text("Apple은 번역 기능의 사용량과 성능 지표(앱 이름, 언어 종류 등)를 수집할 수 있지만, 원문이나 번역 결과는 포함되지 않아요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("데이터와 개인정보")
        .navigationBarTitleDisplayMode(.inline)
    }
}
