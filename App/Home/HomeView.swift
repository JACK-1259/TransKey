import SwiftUI

/// 체험 탭: 연결 상태 확인 + 직접 입력해 보기.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    private var autofocus: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-autofocusTestField")
        #else
        false
        #endif
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TestInputField(autofocus: autofocus)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text("직접 써 보기")
                } footer: {
                    Text("🌐 키로 TransKey로 바꾼 뒤 '사과'를 입력하면 키보드 위에 영어·일본어 번역이 떠요.")
                }

                Section("연결 상태") {
                    KeyboardStatusView()
                    if !appState.isKeyboardConnected || !appState.hasFullAccess {
                        Button {
                            appState.openSystemSettings(using: openURL)
                        } label: {
                            Label("설정 열기", systemImage: "gear")
                        }
                    }
                }
            }
            .navigationTitle("TransKey")
        }
    }
}
