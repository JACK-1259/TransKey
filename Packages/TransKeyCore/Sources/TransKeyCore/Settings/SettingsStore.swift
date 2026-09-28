import Foundation

/// 설정 저장소 추상화. 테스트에서는 메모리 구현으로 교체한다.
public protocol SettingsStoring: Sendable {
    func load() -> TransKeySettings
    func save(_ settings: TransKeySettings)
}

/// App Group `UserDefaults`에 JSON으로 설정을 저장한다.
public final class UserDefaultsSettingsStore: SettingsStoring, @unchecked Sendable {
    // UserDefaults는 스레드 안전하다. 인스턴스는 생성 후 변경되지 않는다.
    private let defaults: UserDefaults
    private let key: String

    public static let storageKey = "transkey.settings.v1"

    public init(defaults: UserDefaults, key: String = UserDefaultsSettingsStore.storageKey) {
        self.defaults = defaults
        self.key = key
    }

    /// App Group 저장소를 사용한다. 엔타이틀먼트가 없어 suite를 만들 수 없으면 표준 저장소로 대체한다.
    public convenience init() {
        self.init(defaults: UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
    }

    public func load() -> TransKeySettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(TransKeySettings.self, from: data) else {
            return .default
        }
        return settings
    }

    public func save(_ settings: TransKeySettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}

/// 테스트와 SwiftUI 프리뷰용 메모리 저장소.
public final class InMemorySettingsStore: SettingsStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var settings: TransKeySettings

    public init(_ settings: TransKeySettings = .default) {
        self.settings = settings
    }

    public func load() -> TransKeySettings {
        lock.withLock { settings }
    }

    public func save(_ settings: TransKeySettings) {
        lock.withLock { self.settings = settings }
    }
}
