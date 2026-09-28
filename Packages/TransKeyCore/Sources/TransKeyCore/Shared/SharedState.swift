import Foundation

/// 키보드가 마지막으로 보고한 상태. 컨테이너 앱이 온보딩/홈 화면에서 연결 여부를 보여줄 때 쓴다.
public struct KeyboardStatus: Codable, Equatable, Sendable {
    public var lastActiveAt: Date
    public var hasFullAccess: Bool

    public init(lastActiveAt: Date, hasFullAccess: Bool) {
        self.lastActiveAt = lastActiveAt
        self.hasFullAccess = hasFullAccess
    }
}

/// 앱과 키보드가 App Group `UserDefaults`로 주고받는 작은 상태들.
/// 사용자가 입력한 텍스트는 절대 여기에 저장하지 않는다.
public final class SharedStateStore: @unchecked Sendable {
    // UserDefaults는 스레드 안전하다. 인스턴스는 생성 후 변경되지 않는다.
    private let defaults: UserDefaults

    private enum Keys {
        static let keyboardStatus = "transkey.keyboardStatus.v1"
        static let cacheResetToken = "transkey.cacheResetToken"
        static let onboardingCompleted = "transkey.onboardingCompleted"
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public convenience init() {
        self.init(defaults: UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
    }

    public var keyboardStatus: KeyboardStatus? {
        get {
            guard let data = defaults.data(forKey: Keys.keyboardStatus) else { return nil }
            return try? JSONDecoder().decode(KeyboardStatus.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                defaults.removeObject(forKey: Keys.keyboardStatus)
                return
            }
            defaults.set(data, forKey: Keys.keyboardStatus)
        }
    }

    /// 앱에서 "캐시 삭제"를 누르면 토큰을 바꾸고, 키보드는 다음에 뜰 때 토큰이 바뀌었으면 캐시를 비운다.
    public var cacheResetToken: String? {
        get { defaults.string(forKey: Keys.cacheResetToken) }
        set { defaults.set(newValue, forKey: Keys.cacheResetToken) }
    }

    public func requestCacheReset() {
        cacheResetToken = UUID().uuidString
    }

    public var onboardingCompleted: Bool {
        get { defaults.bool(forKey: Keys.onboardingCompleted) }
        set { defaults.set(newValue, forKey: Keys.onboardingCompleted) }
    }
}
