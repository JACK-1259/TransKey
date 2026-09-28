import TransKeyCore
import UIKit

@MainActor
protocol CandidateBarViewDelegate: AnyObject {
    func candidateBar(_ bar: CandidateBarView, didSelect text: String, language: Language, chip: CandidateChipView)
    func candidateBarDidRequestRetry(_ bar: CandidateBarView)
}

/// 키보드 최상단 후보 바. iOS 자동완성 바처럼 칩을 균등 분할해 보여준다.
///
/// `render(_:)`가 코디네이터 상태를 받아 화면을 결정한다.
/// - `.empty` → 안내 문구("단어를 입력하면 번역돼요")
/// - `.active` → 성공·로딩 중인 칩만 보여주고, 실패한 칩은 숨긴다.
///   모두 실패했는데 원인이 언어 팩 미설치라면 "앱에서 언어 팩을 받아 주세요"를 보여준다.
/// - 칩을 탭하면 델리게이트(컨트롤러)가 입력과 복사를 처리하고, 이 뷰는 토스트만 띄운다.
final class CandidateBarView: UIView {
    weak var delegate: CandidateBarViewDelegate?

    private let messageLabel = UILabel()
    private let stack = UIStackView()
    private let toastLabel = PaddedLabel()
    private var chips: [CandidateChipView] = []
    private var toastTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = KeyboardTheme.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.adjustsFontSizeToFitWidth = true
        messageLabel.minimumScaleFactor = 0.8

        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill

        toastLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        toastLabel.textColor = .white
        toastLabel.backgroundColor = UIColor(white: 0.15, alpha: 0.9)
        toastLabel.layer.cornerRadius = 11
        toastLabel.layer.masksToBounds = true
        toastLabel.textAlignment = .center
        toastLabel.alpha = 0
        toastLabel.isAccessibilityElement = false

        for view in [messageLabel, stack, toastLabel] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            toastLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            toastLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            toastLabel.heightAnchor.constraint(equalToConstant: 22)
        ])
        showMessage(String(localized: "단어를 입력하면 번역돼요"))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func showMessage(_ message: String) {
        messageLabel.text = message
        messageLabel.isHidden = false
        stack.isHidden = true
    }

    func render(_ state: TranslationCoordinator.BarState, idleMessage: String) {
        switch state {
        case .empty:
            showMessage(idleMessage)
        case .active(_, let allChips):
            // 번역에 실패한 칩(미지원, 언어 팩 없음, 오류)은 숨긴다.
            let visibleChips = allChips.filter {
                if case .failure = $0.state { return false }
                return true
            }
            guard !visibleChips.isEmpty else {
                let needsLanguagePack = allChips.contains { $0.state == .failure(.languagePackMissing) }
                showMessage(needsLanguagePack ? String(localized: "TransKey 앱에서 언어 팩을 받아 주세요") : "")
                return
            }
            messageLabel.isHidden = true
            stack.isHidden = false
            if chips.map(\.language) != visibleChips.map(\.language) {
                rebuildChips(for: visibleChips.map(\.language))
            }
            for (view, chip) in zip(chips, visibleChips) {
                view.apply(chip.state)
            }
        }
    }

    func showToast(_ text: String, duration: Duration = .milliseconds(800)) {
        toastTask?.cancel()
        toastLabel.text = text
        UIAccessibility.post(notification: .announcement, argument: text)
        // 토스트가 떠 있는 동안에는 아래 칩/안내 문구를 흐리게 해 글자가 겹치지 않게 한다.
        UIView.animate(withDuration: 0.15) {
            self.toastLabel.alpha = 1
            self.messageLabel.alpha = 0
            self.stack.alpha = 0.3
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            UIView.animate(withDuration: 0.2) {
                self?.toastLabel.alpha = 0
                self?.messageLabel.alpha = 1
                self?.stack.alpha = 1
            }
        }
    }

    private func rebuildChips(for languages: [Language]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        chips = languages.map { language in
            let chip = CandidateChipView(language: language)
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            return chip
        }
        for (index, chip) in chips.enumerated() {
            stack.addArrangedSubview(chip)
            if index < chips.count - 1 {
                let separator = SeparatorView()
                chip.addSubview(separator)
                separator.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    separator.trailingAnchor.constraint(equalTo: chip.trailingAnchor),
                    separator.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
                    separator.widthAnchor.constraint(equalToConstant: 1),
                    separator.heightAnchor.constraint(equalTo: chip.heightAnchor, multiplier: 0.5)
                ])
            }
        }
        bringSubviewToFront(toastLabel)
    }

    @objc private func chipTapped(_ chip: CandidateChipView) {
        switch chip.chipState {
        case .success(let text):
            delegate?.candidateBar(self, didSelect: text, language: chip.language, chip: chip)
        case .failure(.languagePackMissing), .failure(.unsupported), .loading:
            break
        case .failure:
            delegate?.candidateBarDidRequestRetry(self)
        }
    }
}

private final class SeparatorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = KeyboardTheme.secondaryText.withAlphaComponent(0.35)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

/// 좌우 여백이 있는 라벨(토스트용).
final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height)
    }
}
