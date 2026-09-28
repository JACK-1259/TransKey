import TransKeyCore
import UIKit

/// 후보 바의 번역 칩 하나: 작은 언어 라벨 + 큰 번역 결과.
final class CandidateChipView: UIControl {
    let language: Language
    private(set) var chipState: TranslationCoordinator.ChipState = .loading

    private let languageLabel = UILabel()
    private let resultLabel = UILabel()
    private let loadingView = LoadingDotsView()
    private let retryIcon = UIImageView()
    private let checkIcon = UIImageView()
    private let highlightLayer = CALayer()

    init(language: Language) {
        self.language = language
        super.init(frame: .zero)

        highlightLayer.cornerRadius = 8
        highlightLayer.opacity = 0
        layer.addSublayer(highlightLayer)

        languageLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        languageLabel.textColor = KeyboardTheme.secondaryText
        languageLabel.text = "\(language.flag) \(language.shortLabel)"
        languageLabel.textAlignment = .center

        resultLabel.font = .systemFont(ofSize: 17, weight: .regular)
        resultLabel.textColor = KeyboardTheme.keyText
        resultLabel.textAlignment = .center
        resultLabel.lineBreakMode = .byTruncatingTail
        resultLabel.adjustsFontSizeToFitWidth = true
        resultLabel.minimumScaleFactor = 0.75

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        retryIcon.image = UIImage(systemName: "arrow.clockwise", withConfiguration: symbolConfig)
        retryIcon.tintColor = KeyboardTheme.secondaryText
        checkIcon.image = UIImage(systemName: "checkmark.circle.fill",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        checkIcon.tintColor = .systemGreen
        checkIcon.alpha = 0

        for view in [languageLabel, resultLabel, loadingView, retryIcon, checkIcon] as [UIView] {
            view.isUserInteractionEnabled = false
            addSubview(view)
        }

        isAccessibilityElement = true
        accessibilityTraits = [.button]
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (chip: CandidateChipView, _) in
            chip.highlightLayer.backgroundColor = KeyboardTheme.characterKey
                .resolvedColor(with: chip.traitCollection).cgColor
        }
        highlightLayer.backgroundColor = KeyboardTheme.characterKey.resolvedColor(with: traitCollection).cgColor
        apply(.loading)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isHighlighted: Bool {
        didSet { highlightLayer.opacity = isHighlighted ? 1 : 0 }
    }

    var translatedText: String? {
        if case .success(let text) = chipState { return text }
        return nil
    }

    func apply(_ newState: TranslationCoordinator.ChipState) {
        chipState = newState
        loadingView.isHidden = true
        retryIcon.isHidden = true
        resultLabel.isHidden = false
        resultLabel.textColor = KeyboardTheme.keyText
        resultLabel.font = .systemFont(ofSize: 17, weight: .regular)

        let languageName = Locale.current.localizedString(forLanguageCode: language.code) ?? language.shortLabel
        switch newState {
        case .loading:
            resultLabel.isHidden = true
            loadingView.isHidden = false
            loadingView.startAnimating()
            accessibilityLabel = String(localized: "\(languageName) 번역 중")
        case .success(let text):
            loadingView.stopAnimating()
            resultLabel.text = text
            accessibilityLabel = "\(languageName), \(text)"
            accessibilityHint = String(localized: "탭하면 입력하고 복사해요")
        case .failure(let error):
            loadingView.stopAnimating()
            switch error {
            case .languagePackMissing:
                resultLabel.text = String(localized: "앱에서 언어 팩 받기")
                resultLabel.font = .systemFont(ofSize: 12, weight: .regular)
                resultLabel.textColor = KeyboardTheme.secondaryText
                accessibilityLabel = String(localized: "\(languageName) 언어 팩이 없어요. TransKey 앱에서 받아 주세요.")
            case .unsupported:
                resultLabel.text = String(localized: "지원 안 함")
                resultLabel.font = .systemFont(ofSize: 12, weight: .regular)
                resultLabel.textColor = KeyboardTheme.secondaryText
                accessibilityLabel = String(localized: "\(languageName) 번역을 지원하지 않아요")
            default:
                resultLabel.text = "—"
                retryIcon.isHidden = false
                accessibilityLabel = String(localized: "\(languageName) 번역 실패")
                accessibilityHint = String(localized: "탭하면 다시 시도해요")
            }
        }
        setNeedsLayout()
    }

    /// 탭 성공 시 체크 표시 애니메이션.
    func playCheckAnimation() {
        checkIcon.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        UIView.animate(withDuration: 0.15, animations: {
            self.checkIcon.alpha = 1
            self.checkIcon.transform = .identity
            self.resultLabel.alpha = 0.2
        }, completion: { _ in
            UIView.animate(withDuration: 0.25, delay: 0.5, options: [], animations: {
                self.checkIcon.alpha = 0
                self.resultLabel.alpha = 1
            })
        })
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        highlightLayer.frame = bounds.insetBy(dx: 3, dy: 3)
        let top: CGFloat = bounds.height > 40 ? 4 : 2
        languageLabel.frame = CGRect(x: 4, y: top, width: bounds.width - 8, height: 12)
        let resultTop = languageLabel.frame.maxY
        let resultFrame = CGRect(x: 8, y: resultTop, width: bounds.width - 16,
                                 height: bounds.height - resultTop - 2)
        resultLabel.frame = resultFrame
        loadingView.frame = resultFrame
        retryIcon.sizeToFit()
        retryIcon.center = CGPoint(x: bounds.midX + 16, y: resultFrame.midY)
        checkIcon.sizeToFit()
        checkIcon.center = CGPoint(x: resultFrame.midX, y: resultFrame.midY)
    }
}

/// 점 3개 로딩 표시.
final class LoadingDotsView: UIView {
    private let dots: [UIView] = (0..<3).map { _ in UIView() }
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        for dot in dots {
            dot.backgroundColor = KeyboardTheme.secondaryText
            dot.layer.cornerRadius = 3
            addSubview(dot)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size: CGFloat = 6
        let spacing: CGFloat = 5
        let total = size * 3 + spacing * 2
        var x = bounds.midX - total / 2
        for dot in dots {
            dot.frame = CGRect(x: x, y: bounds.midY - size / 2, width: size, height: size)
            x += size + spacing
        }
    }

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        for (index, dot) in dots.enumerated() {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1
            animation.toValue = 0.25
            animation.duration = 0.5
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.15
            dot.layer.add(animation, forKey: "pulse")
        }
    }

    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        dots.forEach { $0.layer.removeAnimation(forKey: "pulse") }
    }
}
