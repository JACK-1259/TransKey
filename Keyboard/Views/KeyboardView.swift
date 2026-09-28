import TransKeyCore
import UIKit

/// 리턴 키 표시 방식. 호스트의 `returnKeyType`에서 결정된다.
struct ReturnKeyAppearance: Equatable {
    var title: String?
    var symbolName: String?
    var isAccent: Bool
    var isEnabled: Bool

    static let `default` = ReturnKeyAppearance(title: nil, symbolName: "return", isAccent: false, isEnabled: true)
}

@MainActor
protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, didTouchDown key: Key)
    func keyboardView(_ view: KeyboardView, didTap key: Key)
    func keyboardViewDidBeginBackspace(_ view: KeyboardView)
    func keyboardViewDidEndBackspace(_ view: KeyboardView)
    /// 지구본 키가 생성될 때마다 호출된다. 컨트롤러가 `handleInputModeList(from:with:)`를 연결한다.
    func keyboardView(_ view: KeyboardView, didCreateGlobeButton button: UIControl)
}

/// 자판 영역. 레이아웃 모델을 받아 키 버튼을 만들고, 지오메트리 계산 결과대로 배치한다.
///
/// ## 그리는 과정
/// 1. `layoutModel`(어떤 키가 어떤 순서로 있는지)이 바뀌면 `rebuildKeys()`가 `KeyButton`을 새로 만든다.
/// 2. `layoutSubviews()`에서 `KeyboardGeometry`가 화면 폭에 맞춰 키마다 위치·크기를 계산한다.
///    (SE부터 Pro Max, 가로 모드까지 같은 코드로 대응)
///
/// ## 터치 처리 과정
/// 1. `hitTest` — 키 사이 빈틈을 눌러도 가장 가까운 키로 보낸다.
/// 2. `touchDown` — 팝업(확대된 글자)을 띄우고, 델리게이트에 알려 소리·햅틱을 낸다.
/// 3. `touchUpInside` — 팝업을 닫고 델리게이트에 "이 키가 눌렸다"고 알린다(실제 입력은 컨트롤러가 한다).
/// 4. 백스페이스는 누르는 순간 시작하고 손을 뗄 때 멈추도록 별도 경로로 보낸다.
final class KeyboardView: UIView {
    weak var delegate: KeyboardViewDelegate?

    /// 팝업을 그릴 상위 뷰. 후보 바 위까지 덮을 수 있도록 키보드 루트 뷰를 지정한다.
    weak var popupContainer: UIView?

    var layoutModel: KeyboardLayout = .english(page: .letters, showsGlobe: true) {
        didSet {
            guard layoutModel != oldValue else { return }
            rebuildKeys()
        }
    }

    var metrics: KeyboardMetrics = .portrait {
        didSet {
            guard metrics != oldValue else { return }
            setNeedsLayout()
        }
    }

    var shiftState: ShiftStateMachine.State = .off {
        didSet {
            guard shiftState != oldValue else { return }
            refreshLabels()
        }
    }

    var returnKeyAppearance: ReturnKeyAppearance = .default {
        didSet {
            guard returnKeyAppearance != oldValue else { return }
            refreshLabels()
        }
    }

    /// 한/영 전환 키 라벨(현재 입력 언어).
    var languageToggleTitle = "한" {
        didSet {
            guard languageToggleTitle != oldValue else { return }
            refreshLabels()
        }
    }

    var spaceTitle = "space" {
        didSet {
            guard spaceTitle != oldValue else { return }
            refreshLabels()
        }
    }

    /// 가로 모드에서는 시스템 키보드처럼 팝업 대신 하이라이트만 쓴다.
    var showsKeyPopups = true

    private var rows: [[KeyButton]] = []
    private let popupView = KeyPopupView()
    private weak var popupOwner: KeyButton?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        popupView.hide()
        rebuildKeys()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let frames = KeyboardGeometry.frames(for: layoutModel, width: bounds.width, metrics: metrics)
        for (rowButtons, rowFrames) in zip(rows, frames) {
            for (button, frame) in zip(rowButtons, rowFrames) {
                button.frame = frame
            }
        }
        if popupView.superview == nil, let container = popupContainer {
            container.addSubview(popupView)
        }
    }

    /// 키 사이 간격이나 가장자리를 눌러도 가장 가까운 키가 입력되도록 한다.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, bounds.contains(point) else { return nil }
        var best: KeyButton?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for button in rows.joined() {
            let frame = button.frame
            if frame.contains(point) { return button }
            let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
            let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                best = button
            }
        }
        return best
    }

    // MARK: - Keys

    private func rebuildKeys() {
        popupView.hide()
        rows.joined().forEach { $0.removeFromSuperview() }
        rows = layoutModel.rows.map { row in
            row.keys.map { key in
                let button = KeyButton(key: key)
                wire(button)
                addSubview(button)
                return button
            }
        }
        refreshLabels()
        setNeedsLayout()
    }

    private func wire(_ button: KeyButton) {
        switch button.key.action {
        case .globe:
            delegate?.keyboardView(self, didCreateGlobeButton: button)
        case .backspace:
            button.addTarget(self, action: #selector(backspaceDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(backspaceUp(_:)),
                             for: [.touchUpInside, .touchUpOutside, .touchCancel])
        default:
            button.addTarget(self, action: #selector(keyDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(keyUpInside(_:)), for: .touchUpInside)
            button.addTarget(self, action: #selector(keyCancelled(_:)),
                             for: [.touchUpOutside, .touchCancel, .touchDragExit])
        }
    }

    /// 지구본 키 연결을 다시 요청한다(델리게이트가 나중에 설정된 경우).
    func rewireGlobeKeys() {
        for button in rows.joined() where button.key.action == .globe {
            delegate?.keyboardView(self, didCreateGlobeButton: button)
        }
    }

    private func refreshLabels() {
        let uppercase = shiftState != .off
        for button in rows.joined() {
            configureLabel(of: button, uppercase: uppercase)
        }
    }

    private func configureLabel(of button: KeyButton, uppercase: Bool) {
        let key = button.key
        switch key.action {
        case .character(let value):
            let text = key.insertedText(uppercased: uppercase) ?? value
            button.configure(title: text, accessibilityLabel: text)
        case .shift:
            let symbol: String
            let label: String
            switch shiftState {
            case .off:
                symbol = "shift"
                label = String(localized: "Shift")
            case .once:
                symbol = "shift.fill"
                label = String(localized: "Shift 켜짐")
            case .locked:
                symbol = "capslock.fill"
                label = String(localized: "Caps Lock 켜짐")
            }
            button.configure(title: nil, symbolName: symbol,
                             style: shiftState == .off ? .function : .character,
                             accessibilityLabel: label)
        case .backspace:
            button.configure(title: nil, symbolName: "delete.left",
                             accessibilityLabel: String(localized: "삭제"))
        case .space:
            button.configure(title: spaceTitle, style: .character,
                             accessibilityLabel: String(localized: "스페이스"))
        case .returnKey:
            let appearance = returnKeyAppearance
            button.configure(title: appearance.title, symbolName: appearance.symbolName,
                             style: appearance.isAccent ? .accent : .function,
                             accessibilityLabel: appearance.title ?? String(localized: "리턴"))
            button.isEnabled = appearance.isEnabled
        case .globe:
            button.configure(title: nil, symbolName: "globe",
                             accessibilityLabel: String(localized: "다음 키보드"))
        case .page(let page):
            let title: String
            switch page {
            case .letters: title = "ABC"
            case .numbers: title = "123"
            case .symbols: title = "#+="
            }
            button.configure(title: title, accessibilityLabel: title)
        case .languageToggle:
            button.configure(title: languageToggleTitle,
                             accessibilityLabel: String(localized: "한영 전환, 현재 \(languageToggleTitle)"))
        }
    }

    // MARK: - Touch handling

    @objc private func keyDown(_ sender: KeyButton) {
        delegate?.keyboardView(self, didTouchDown: sender.key)
        guard showsKeyPopups, sender.key.isCharacter, let container = popupContainer else { return }
        let text = sender.key.insertedText(uppercased: shiftState != .off) ?? ""
        let keyFrame = convert(sender.frame, to: container)
        container.bringSubviewToFront(popupView)
        popupView.show(text: text, keyFrame: keyFrame, in: container.bounds)
        popupOwner = sender
    }

    @objc private func keyUpInside(_ sender: KeyButton) {
        hidePopup(for: sender)
        delegate?.keyboardView(self, didTap: sender.key)
    }

    @objc private func keyCancelled(_ sender: KeyButton) {
        hidePopup(for: sender)
    }

    @objc private func backspaceDown(_ sender: KeyButton) {
        delegate?.keyboardView(self, didTouchDown: sender.key)
        delegate?.keyboardViewDidBeginBackspace(self)
    }

    @objc private func backspaceUp(_ sender: KeyButton) {
        delegate?.keyboardViewDidEndBackspace(self)
    }

    private func hidePopup(for sender: KeyButton) {
        // 빠른 연타 중 다른 손가락이 띄운 팝업은 건드리지 않는다.
        guard popupOwner === sender else { return }
        popupView.hide()
        popupOwner = nil
    }
}
