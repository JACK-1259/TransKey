import UIKit

/// 키보드 루트 뷰. `UIInputViewAudioFeedback`을 채택해야 `UIDevice.playInputClick()`이 소리를 낸다.
final class KeyboardInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
