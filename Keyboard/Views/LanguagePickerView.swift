import TransKeyCore
import UIKit

@MainActor
protocol LanguagePickerViewDelegate: AnyObject {
    func languagePicker(_ picker: LanguagePickerView, didFinishWith selection: [Language])
}

/// 키보드 안에서 번역 언어를 고르는 패널. 자판 자리를 덮어 보여준다.
///
/// 무료 개발자 계정 빌드처럼 앱과 설정을 공유할 수 없을 때도, 키보드에서 직접 고른 언어를
/// 키보드에 저장해 쓸 수 있게 하기 위해 만들었다. 언어 팩이 설치된 언어만 고를 수 있고, 최대 3개다.
final class LanguagePickerView: UIView {
    weak var delegate: LanguagePickerViewDelegate?

    private(set) var selection: [Language]
    private var buttons: [Language: UIButton] = [:]

    private let titleLabel = UILabel()
    private let hintLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let grid = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(selection: [Language]) {
        self.selection = selection
        super.init(frame: .zero)
        backgroundColor = .clear

        titleLabel.text = String(localized: "번역 언어")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = KeyboardTheme.keyText

        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = KeyboardTheme.secondaryText
        updateHint()

        var doneConfig = UIButton.Configuration.filled()
        doneConfig.title = String(localized: "완료")
        doneConfig.cornerStyle = .capsule
        doneConfig.buttonSize = .small
        doneButton.configuration = doneConfig
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        grid.axis = .vertical
        grid.spacing = 8
        scrollView.addSubview(grid)
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true

        let header = UIStackView(arrangedSubviews: [titleLabel, hintLabel, UIView(), doneButton])
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center

        for subview in [header, scrollView, spinner] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }
        grid.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            header.heightAnchor.constraint(equalToConstant: 32),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),

            grid.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            grid.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            grid.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func showLoading() {
        spinner.startAnimating()
    }

    /// 언어 팩이 설치된 언어로 버튼을 만든다. 설치되지 않은 언어는 고를 수 없다.
    func show(installed: [Language]) {
        spinner.stopAnimating()
        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        // 지금 선택돼 있어도 언어 팩이 지워졌다면 선택에서 뺀다.
        selection = selection.filter { installed.contains($0) }

        guard !installed.isEmpty else {
            let empty = UILabel()
            empty.text = String(localized: "설치된 언어 팩이 없어요. TransKey 앱에서 받아 주세요.")
            empty.font = .systemFont(ofSize: 14)
            empty.textColor = KeyboardTheme.secondaryText
            empty.numberOfLines = 0
            empty.textAlignment = .center
            grid.addArrangedSubview(empty)
            updateHint()
            return
        }

        let columns = 3
        stride(from: 0, to: installed.count, by: columns).forEach { start in
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.distribution = .fillEqually
            for language in installed[start..<min(start + columns, installed.count)] {
                let button = makeButton(for: language)
                buttons[language] = button
                row.addArrangedSubview(button)
            }
            // 마지막 줄 칸 수를 맞춰 버튼 폭을 일정하게 유지한다.
            for _ in row.arrangedSubviews.count..<columns {
                row.addArrangedSubview(UIView())
            }
            grid.addArrangedSubview(row)
        }
        refreshButtons()
        updateHint()
    }

    private func makeButton(for language: Language) -> UIButton {
        let button = UIButton(type: .system)
        button.addAction(UIAction { [weak self] _ in self?.toggle(language) }, for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.accessibilityLabel = language.displayName()
        return button
    }

    private func toggle(_ language: Language) {
        if let index = selection.firstIndex(of: language) {
            // 최소 1개는 남겨 둔다.
            guard selection.count > 1 else { flashHint(String(localized: "최소 1개는 골라야 해요")); return }
            selection.remove(at: index)
        } else {
            guard selection.count < Language.maxEnabledTargets else {
                flashHint(String(localized: "최대 \(Language.maxEnabledTargets)개까지 고를 수 있어요"))
                return
            }
            selection.append(language)
        }
        UISelectionFeedbackGenerator(view: self).selectionChanged()
        refreshButtons()
        updateHint()
    }

    private func refreshButtons() {
        for (language, button) in buttons {
            let isOn = selection.contains(language)
            var config = isOn ? UIButton.Configuration.filled() : UIButton.Configuration.gray()
            config.title = "\(language.flag) \(language.displayName())"
            config.titleLineBreakMode = .byTruncatingTail
            config.cornerStyle = .medium
            config.image = isOn ? UIImage(systemName: "checkmark") : nil
            config.imagePadding = 4
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = .systemFont(ofSize: 14, weight: isOn ? .semibold : .regular)
                return attributes
            }
            button.configuration = config
            button.accessibilityTraits = isOn ? [.button, .selected] : [.button]
        }
    }

    private func updateHint() {
        hintLabel.text = "\(selection.count)/\(Language.maxEnabledTargets)"
    }

    private func flashHint(_ message: String) {
        hintLabel.text = message
        hintLabel.textColor = .systemOrange
        UINotificationFeedbackGenerator(view: self).notificationOccurred(.warning)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            self?.hintLabel.textColor = KeyboardTheme.secondaryText
            self?.updateHint()
        }
    }

    @objc private func doneTapped() {
        guard !selection.isEmpty || buttons.isEmpty else {
            flashHint(String(localized: "최소 1개는 골라야 해요"))
            return
        }
        delegate?.languagePicker(self, didFinishWith: selection)
    }
}
