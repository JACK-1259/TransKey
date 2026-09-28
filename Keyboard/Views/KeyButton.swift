import TransKeyCore
import UIKit

/// 키 하나. 배경과 그림자는 레이어로 직접 그려 뷰 계층을 가볍게 유지한다.
final class KeyButton: UIControl {
    enum Style {
        case character
        case function
        case accent
    }

    let key: Key
    private(set) var style: Style
    private let titleLabel = UILabel()
    private let iconView = UIImageView()

    init(key: Key) {
        self.key = key
        self.style = key.isCharacter ? .character : .function
        super.init(frame: .zero)

        isExclusiveTouch = false
        layer.cornerRadius = KeyboardTheme.keyCornerRadius
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 1
        layer.shadowRadius = 0

        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.6
        titleLabel.isUserInteractionEnabled = false
        iconView.contentMode = .center
        iconView.isUserInteractionEnabled = false
        addSubview(titleLabel)
        addSubview(iconView)

        isAccessibilityElement = true
        accessibilityTraits = [.keyboardKey]

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (button: KeyButton, _) in
            button.updateColors()
        }
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isHighlighted: Bool {
        didSet { updateColors() }
    }

    override var isEnabled: Bool {
        didSet { updateColors() }
    }

    /// 텍스트 또는 SF Symbol로 키 내용을 설정한다.
    func configure(title: String?, symbolName: String? = nil, style: Style? = nil,
                   accessibilityLabel: String) {
        if let style { self.style = style }
        titleLabel.text = title
        titleLabel.isHidden = title == nil
        if let symbolName {
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            iconView.image = UIImage(systemName: symbolName, withConfiguration: config)
            iconView.isHidden = false
        } else {
            iconView.image = nil
            iconView.isHidden = true
        }
        let isLetter = key.isCharacter && (title?.count ?? 0) == 1
        titleLabel.font = isLetter
            ? .systemFont(ofSize: 24, weight: .regular)
            : .systemFont(ofSize: 16, weight: .regular)
        self.accessibilityLabel = accessibilityLabel
        updateColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = bounds.insetBy(dx: 2, dy: 0)
        iconView.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds,
                                        cornerRadius: KeyboardTheme.keyCornerRadius).cgPath
    }

    private func updateColors() {
        let background: UIColor
        var foreground = KeyboardTheme.keyText
        switch style {
        case .character:
            background = isHighlighted ? KeyboardTheme.functionKey : KeyboardTheme.characterKey
        case .function:
            background = isHighlighted ? KeyboardTheme.characterKey : KeyboardTheme.functionKey
        case .accent:
            background = isHighlighted ? KeyboardTheme.functionKey : KeyboardTheme.accentKey
            foreground = .white
        }
        let traits = traitCollection
        layer.backgroundColor = background.resolvedColor(with: traits).cgColor
        layer.shadowColor = KeyboardTheme.keyShadow.resolvedColor(with: traits).cgColor
        titleLabel.textColor = foreground
        iconView.tintColor = foreground
        alpha = isEnabled ? 1 : 0.5
    }
}
