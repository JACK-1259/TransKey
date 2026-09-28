import SwiftUI

/// 온보딩을 마치기 전에는 온보딩, 이후에는 탭 화면을 보여준다.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.onboardingCompleted {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.default, value: appState.onboardingCompleted)
        .onChange(of: scenePhase) { _, phase in
            // 설정 앱에서 키보드를 켜고 돌아오면 상태를 다시 읽는다.
            if phase == .active {
                appState.refreshKeyboardStatus()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("체험", systemImage: "keyboard") {
                HomeView()
            }
            Tab("언어 팩", systemImage: "arrow.down.circle") {
                NavigationStack {
                    LanguagePackView()
                }
            }
            Tab("설정", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}
