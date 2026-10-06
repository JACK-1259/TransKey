import Observation
import SwiftUI
import TransKeyCore

/// 컨테이너 앱 전역 상태. 설정은 App Group에 저장돼 키보드와 공유된다.
///
/// ## 앱 ↔ 키보드 데이터 흐름
/// - 설정 화면에서 값을 바꾸면 `settings`의 `didSet`이 곧바로 App Group에 저장한다.
///   → 키보드는 다음에 화면에 나타날 때(`viewWillAppear`) 읽어 간다.
/// - 키보드는 나타날 때마다 "마지막 실행 시각·전체 접근 여부"를 기록한다.
///   → 앱은 `refreshKeyboardStatus()`로 읽어서 연결 상태(✅)를 보여준다.
/// - "캐시 삭제"는 앱이 토큰을 바꾸고, 키보드가 바뀐 토큰을 보면 캐시를 비우는 방식이다.
@MainActor
@Observable
final class AppState {
    var settings: TransKeySettings {
        didSet {
            guard settings != oldValue else { return }
            settingsStore.save(settings)
        }
    }

    var onboardingCompleted: Bool {
        didSet { sharedState.onboardingCompleted = onboardingCompleted }
    }

    private(set) var keyboardStatus: KeyboardStatus?

    private let settingsStore: any SettingsStoring
    private let sharedState: SharedStateStore

    init(settingsStore: any SettingsStoring = UserDefaultsSettingsStore(),
         sharedState: SharedStateStore = SharedStateStore()) {
        self.settingsStore = settingsStore
        self.sharedState = sharedState
        self.settings = settingsStore.load()
        self.onboardingCompleted = sharedState.onboardingCompleted
        self.keyboardStatus = sharedState.keyboardStatus

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-resetOnboarding") { onboardingCompleted = false }
        if arguments.contains("-skipOnboarding") { onboardingCompleted = true }
        #endif
    }

    /// 키보드는 화면에 뜰 때마다 상태를 기록한다. 앱이 다시 활성화될 때 읽어 온다.
    func refreshKeyboardStatus() {
        keyboardStatus = sharedState.keyboardStatus
    }

    var isKeyboardConnected: Bool { keyboardStatus != nil }
    var hasFullAccess: Bool { keyboardStatus?.hasFullAccess ?? false }

    /// 키보드의 번역 캐시 삭제를 요청한다. 키보드가 다음에 뜰 때 반영된다.
    func clearTranslationCache() {
        sharedState.requestCacheReset()
    }

    /// 번역 언어를 켜거나 끈다. 최소 1개, 최대 3개를 지켜야 하며 바꾸지 못하면 false.
    @discardableResult
    func setTarget(_ language: Language, enabled: Bool) -> Bool {
        var targets = settings.enabledTargets
        if enabled {
            guard targets.contains(language) || settings.canEnableMoreTargets else { return false }
            targets.insert(language)
        } else {
            // 번역 언어는 최소 하나는 켜져 있어야 한다.
            guard targets.count > 1 || !targets.contains(language) else { return false }
            targets.remove(language)
        }
        settings.enabledTargets = targets
        return true
    }

    func openSystemSettings(using openURL: OpenURLAction) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}
