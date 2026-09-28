import SwiftUI

/// 키보드 연결 여부와 전체 접근 상태. 키보드가 한 번이라도 뜨면 App Group에 기록된 값을 보여준다.
struct KeyboardStatusView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusRow(
                isOn: appState.isKeyboardConnected,
                onText: "TransKey 키보드가 연결됐어요",
                offText: "아직 TransKey 키보드를 쓴 적이 없어요"
            )
            StatusRow(
                isOn: appState.hasFullAccess,
                onText: "전체 접근이 켜져 있어요 (복사 가능)",
                offText: "전체 접근이 꺼져 있어요 (복사 안 됨)"
            )
        }
        .accessibilityElement(children: .combine)
        .task {
            // 같은 앱 안에서 키보드를 띄우면 scenePhase가 바뀌지 않으므로, 보이는 동안 주기적으로 다시 읽는다.
            while !Task.isCancelled {
                appState.refreshKeyboardStatus()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct StatusRow: View {
    let isOn: Bool
    let onText: LocalizedStringKey
    let offText: LocalizedStringKey

    var body: some View {
        Label {
            Text(isOn ? onText : offText)
                .foregroundStyle(isOn ? .primary : .secondary)
        } icon: {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(isOn ? .green : .secondary)
        }
    }
}
