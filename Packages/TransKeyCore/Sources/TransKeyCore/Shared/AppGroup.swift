import Foundation

/// 컨테이너 앱과 키보드 익스텐션이 공유하는 App Group 식별자.
/// 실제 배포 전 Apple Developer 계정에 등록한 값으로 교체해야 한다.
public enum AppGroup {
    public static let identifier = "group.com.jack1259.transkey"

    /// App Group 컨테이너 URL. 엔타이틀먼트가 없는 환경(서명 없는 빌드, 테스트)에서는 nil.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// 앱과 키보드가 설정을 공유할 수 있는지.
    /// 무료 개발자 계정 빌드처럼 App Group 권한 없이 설치되면 false이고,
    /// 이때 키보드는 앱에서 고른 번역 언어를 읽을 수 없다.
    public static var isAvailable: Bool { containerURL != nil }
}
