import Foundation

/// 컨테이너 앱과 키보드 익스텐션이 공유하는 App Group 식별자.
/// 실제 배포 전 Apple Developer 계정에 등록한 값으로 교체해야 한다.
public enum AppGroup {
    public static let identifier = "group.com.example.transkey"

    /// App Group 컨테이너 URL. 엔타이틀먼트가 없는 환경(서명 없는 빌드, 테스트)에서는 nil.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
