import UIKit

/// 키 입력 피드백(햅틱, 클릭음).
/// 키보드 익스텐션의 햅틱은 전체 접근이 있어야 동작하므로 없으면 시도하지 않는다.
@MainActor
final class KeyFeedback {
    private weak var view: UIView?
    private var impactGenerator: UIImpactFeedbackGenerator?

    var hapticsEnabled = true
    var soundEnabled = true
    var hasFullAccess = false

    init(view: UIView) {
        self.view = view
    }

    func prepare() {
        guard hapticsEnabled, hasFullAccess, let view else { return }
        let generator = impactGenerator ?? UIImpactFeedbackGenerator(style: .light, view: view)
        generator.prepare()
        impactGenerator = generator
    }

    /// 키를 누르는 순간 호출한다.
    func keyDown(withHaptic: Bool = true) {
        if soundEnabled {
            UIDevice.current.playInputClick()
        }
        guard withHaptic, hapticsEnabled, hasFullAccess else { return }
        if impactGenerator == nil { prepare() }
        impactGenerator?.impactOccurred()
    }
}
