import TransKeyCore
import UIKit

/// TransKey 키보드 익스텐션의 진입점(Info.plist의 NSExtensionPrincipalClass).
///
/// ## 한 번의 입력이 처리되는 전체 흐름
/// 1. 사용자가 🌐 키로 TransKey를 고르면 iOS가 이 컨트롤러를 만들고
///    `loadView` → `viewDidLoad` → `viewWillAppear` 순서로 호출한다.
/// 2. 키를 누르면 `KeyboardView`가 델리게이트로 알려 준다.
///    - 손가락이 닿는 순간(`didTouchDown`): 클릭음·햅틱만 낸다.
///    - 손가락을 뗄 때(`didTap`): 실제로 글자를 입력한다.
/// 3. 키보드는 다른 앱의 입력창에 직접 접근할 수 없다. 대신 iOS가 주는
///    `textDocumentProxy`(입력창 대리 객체)로 글자를 넣고(`insertText`) 지운다(`deleteBackward`).
/// 4. 한국어 자판이면 `HangulComposer`가 자모를 음절로 조합한다.
///    조합 중인 글자는 "지우고 다시 쓰기" 방식으로 갱신한다(아래 Hangul composition 참고).
/// 5. 입력·삭제가 끝날 때마다 `scheduleTranslation()`이 커서 앞 단어를 뽑아
///    `TranslationCoordinator`에 넘긴다.
/// 6. 코디네이터는 입력이 0.3초 멈추면 번역하고, 상태가 바뀔 때마다 `onChange`로 알려 준다.
///    → `CandidateBarView`가 EN/JA 칩으로 그린다.
/// 7. 칩을 탭하면 원문을 지우고 번역문을 넣은 뒤, 전체 접근이 켜져 있으면 클립보드에도 복사한다.
final class KeyboardViewController: UIInputViewController {
    private enum Constants {
        static let candidateBarHeightPortrait: CGFloat = 44
        static let candidateBarHeightLandscape: CGFloat = 36
        static let backspaceInitialDelay: Duration = .milliseconds(450)
        static let backspaceSlowInterval: Duration = .milliseconds(90)
        static let backspaceFastInterval: Duration = .milliseconds(50)
        static let backspaceAccelerateAfter = 15
        static let doubleSpaceInterval: TimeInterval = 0.35
        static let inputLanguageKey = "transkey.inputLanguage"
        static let fullAccessHintKey = "transkey.didShowFullAccessHint"
        static let autoTargetsKey = "transkey.autoSelectedTargets"
        static let keyboardTargetsKey = "transkey.keyboardSelectedTargets"
    }

    // 앱과 공유하는 저장소(App Group). 설정값, 입력 언어, 키보드 상태만 저장하고
    // 사용자가 입력한 텍스트는 절대 저장하지 않는다.
    private let settingsStore: any SettingsStoring
    private let sharedDefaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    private let sharedState = SharedStateStore()
    private var appliedCacheResetToken: String?
    private var settings = TransKeySettings.default

    // 화면 구성: 위쪽 후보 바(번역 칩) + 아래쪽 자판.
    private let candidateBar = CandidateBarView()
    private let keyboardView = KeyboardView()
    private lazy var feedback = KeyFeedback(view: view)
    // 첫 번역 때 기기가 번역 모델을 불러오느라 몇 초 걸릴 수 있어 타임아웃을 넉넉히 둔다.
    private lazy var coordinator = TranslationCoordinator(provider: Self.makeProvider(), timeout: .seconds(10))

    private var heightConstraint: NSLayoutConstraint?
    private var candidateBarHeightConstraint: NSLayoutConstraint?

    private var inputLanguage: InputLanguage = .korean
    private var page: KeyboardPage = .letters
    private var shift = ShiftStateMachine()
    private var showsGlobe = true
    private var backspaceTask: Task<Void, Never>?
    private var lastSpaceTime: TimeInterval?

    /// 한글 조합기와, 현재 문서에 그려져 있는 조합 중 글자.
    private var composer = HangulComposer()
    private var composingInDocument = ""

    /// 칩으로 번역문을 넣은 직후에는 그 번역문을 다시 번역하지 않는다(다음 키 입력 전까지).
    private var suppressTranslation = false

    /// 시스템이 익스텐션을 띄울 때 호출하는 이니셜라이저. 반드시 오버라이드해야 한다.
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.settingsStore = UserDefaultsSettingsStore()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    /// 테스트용 의존성 주입 이니셜라이저.
    init(settingsStore: any SettingsStoring) {
        self.settingsStore = settingsStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.settingsStore = UserDefaultsSettingsStore()
        super.init(coder: coder)
    }

    /// 번역 엔진을 고른다. `TranslationProvider` 프로토콜 덕분에 엔진을 바꿔도 나머지 코드는 그대로다.
    private static func makeProvider() -> any TranslationProvider {
        #if targetEnvironment(simulator)
        // 온디바이스 번역은 시뮬레이터에서 동작하지 않아 데모 사전으로 폴백한다.
        FallbackTranslationProvider(primary: AppleOnDeviceProvider(), secondary: SimulatorDemoProvider())
        #else
        AppleOnDeviceProvider()
        #endif
    }

    // MARK: - Lifecycle

    /// ① 키보드의 루트 뷰를 만든다. `KeyboardInputView`는 키 클릭음을 켜기 위한 UIInputView다.
    override func loadView() {
        let inputView = KeyboardInputView(frame: .zero, inputViewStyle: .keyboard)
        inputView.allowsSelfSizing = true
        view = inputView
    }

    /// ② 뷰를 한 번 구성한다: 후보 바와 자판 배치, 델리게이트 연결, 높이 제약, 번역 상태 구독.
    override func viewDidLoad() {
        super.viewDidLoad()
        // iOS 26+ 시스템 키보드 배경(유리 효과)을 그대로 쓰기 위해 투명하게 둔다.
        view.backgroundColor = .clear

        if let saved = sharedDefaults.string(forKey: Constants.inputLanguageKey),
           let language = InputLanguage(rawValue: saved) {
            inputLanguage = language
        }

        candidateBar.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(candidateBar)
        view.addSubview(keyboardView)

        candidateBar.delegate = self
        keyboardView.delegate = self
        keyboardView.popupContainer = view
        applyLayout()
        keyboardView.rewireGlobeKeys()

        // 번역 상태(로딩/결과/실패)가 바뀔 때마다 후보 바를 다시 그린다.
        coordinator.onChange = { [weak self] state in
            self?.renderCandidateBar(state)
        }

        let barHeight = candidateBar.heightAnchor.constraint(equalToConstant: Constants.candidateBarHeightPortrait)
        candidateBarHeightConstraint = barHeight
        NSLayoutConstraint.activate([
            candidateBar.topAnchor.constraint(equalTo: view.topAnchor),
            candidateBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            candidateBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            barHeight,
            keyboardView.topAnchor.constraint(equalTo: candidateBar.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 시스템 권장: 입력 뷰 높이 제약은 필수보다 한 단계 낮은 우선순위로 둔다.
        let height = view.heightAnchor.constraint(equalToConstant: preferredHeight())
        height.priority = .required - 1
        height.isActive = true
        heightConstraint = height

        registerForTraitChanges(
            [UITraitVerticalSizeClass.self, UITraitUserInterfaceStyle.self]
        ) { (controller: KeyboardViewController, _) in
            controller.applyMetrics()
            controller.updateAppearance()
        }
    }

    /// ③ 키보드가 화면에 나타날 때마다 호출된다.
    /// 앱에서 바꾼 설정을 여기서 다시 읽으므로, 설정 변경은 키보드를 다시 열 때 반영된다.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settings = settingsStore.load()
        if !AppGroup.isAvailable {
            // 키보드에서 직접 고른 언어가 있으면 그것을, 없으면 설치된 언어 팩에서 자동으로 고른다.
            if let picked = sharedDefaults.stringArray(forKey: Constants.keyboardTargetsKey), !picked.isEmpty {
                settings.enabledTargets = Set(picked.map { Language(rawValue: $0) })
            } else {
                applyInstalledLanguageFallback()
            }
        }
        feedback.hapticsEnabled = settings.hapticsEnabled
        feedback.soundEnabled = settings.keySoundEnabled
        feedback.hasFullAccess = hasFullAccess
        feedback.prepare()
        reportStatusAndApplyRequests()
        resetComposition()
        appliedSecureState = nil
        refreshFromDocument()
    }

    // MARK: - 설정 공유가 안 될 때의 번역 언어
    //
    // 무료 개발자 계정 빌드처럼 App Group 없이 설치되면 키보드는 앱에서 고른 번역 언어를 읽을 수 없다.
    // 대신 아이폰 전체가 공유하는 언어 팩 설치 상태를 키보드가 직접 확인해서,
    // 설치된 언어 중 앞의 최대 3개(영어 → 일본어 → 중국어 → 스페인어 … 순)를 칩으로 보여준다.

    private var installedLanguagesTask: Task<Void, Never>?
    private var languagePicker: LanguagePickerView?

    private func applyInstalledLanguageFallback() {
        // 1) 지난번에 확인한 목록을 바로 적용해 칩이 즉시 올바르게 뜨게 한다.
        if let cached = sharedDefaults.stringArray(forKey: Constants.autoTargetsKey), !cached.isEmpty {
            settings.enabledTargets = Set(cached.map { Language(rawValue: $0) })
        }
        // 2) 백그라운드에서 다시 확인하고, 바뀌었으면 저장하고 칩을 갱신한다.
        installedLanguagesTask?.cancel()
        installedLanguagesTask = Task { [weak self] in
            let installed = await AppleOnDeviceProvider.installedTargets()
            guard let self, !Task.isCancelled, !installed.isEmpty else { return }
            let targets = Language.autoSelectedTargets(fromInstalled: installed)
            guard targets != self.settings.enabledTargets else { return }
            self.settings.enabledTargets = targets
            self.sharedDefaults.set(targets.sorted(by: Language.displayOrder).map(\.code),
                                    forKey: Constants.autoTargetsKey)
            self.scheduleTranslation()
        }
    }

    /// 앱이 연결 상태를 보여줄 수 있도록 상태를 기록하고, 앱에서 요청한 캐시 삭제를 반영한다.
    private func reportStatusAndApplyRequests() {
        sharedState.keyboardStatus = KeyboardStatus(lastActiveAt: Date(), hasFullAccess: hasFullAccess)
        let token = sharedState.cacheResetToken
        if token != appliedCacheResetToken {
            if appliedCacheResetToken != nil || token != nil {
                coordinator.clearCache()
            }
            appliedCacheResetToken = token
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // needsInputModeSwitchKey는 뷰가 화면에 붙은 뒤에야 정확하므로 레이아웃 시점마다 확인한다.
        let needsGlobe = needsInputModeSwitchKey
        if needsGlobe != showsGlobe {
            showsGlobe = needsGlobe
            applyLayout()
        }
        applyMetrics()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopBackspaceRepeat()
        resetComposition()
        coordinator.clear()
    }

    /// ④ 키보드가 화면에 완전히 나타난 뒤.
    /// iOS는 화면 가장자리(좌우 끝, 맨 아래)에서 시스템 제스처(뒤로 가기, 홈)를 먼저 확인하느라
    /// 키보드 터치를 잠깐 붙잡아 둔다. 그래서 ㅂ·ㅔ·ㅁ·ㅣ 같은 끝 키나 맨 아래 줄이 늦게 반응한다.
    /// 창의 제스처 인식기가 터치를 지연시키지 않도록 꺼서 기본 키보드처럼 바로 반응하게 한다.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.window?.gestureRecognizers?.forEach { $0.delaysTouchesBegan = false }
        view.window?.superview?.gestureRecognizers?.forEach { $0.delaysTouchesBegan = false }
    }

    // MARK: - UITextInputDelegate

    // iOS가 "입력창 내용이나 커서가 바뀌었다"고 알려 주는 콜백.
    // 사용자가 입력창을 직접 탭해서 커서를 옮기거나, 앱이 텍스트를 바꿨을 때 호출된다.
    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        syncCompositionWithDocument()
        refreshFromDocument()
    }

    override func selectionDidChange(_ textInput: (any UITextInput)?) {
        super.selectionDidChange(textInput)
        syncCompositionWithDocument()
        updateAutoCapitalization()
        scheduleDeferredUpdates()
    }

    // MARK: - State → View

    private func refreshFromDocument() {
        updateAppearance()
        updateSecureState()
        updateAutoCapitalization()
        scheduleDeferredUpdates()
    }

    /// 키 입력 직후에 꼭 하지 않아도 되는 일(리턴 키 갱신, 번역 요청)을 다음 실행 주기로 미룬다.
    /// 빠르게 여러 키를 눌러도 한 번으로 합쳐지고, 키 입력 처리 자체는 바로 끝나서 반응이 빨라진다.
    private var hasPendingDeferredUpdates = false

    private func scheduleDeferredUpdates() {
        guard !hasPendingDeferredUpdates else { return }
        hasPendingDeferredUpdates = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hasPendingDeferredUpdates = false
            self.updateReturnKey()
            self.scheduleTranslation()
        }
    }

    /// 비밀번호 등 보안 입력창인지. 이때는 번역, 네트워크, 로깅을 모두 끈다.
    private var isSecureContext: Bool {
        textDocumentProxy.isSecureTextEntry == true
    }

    private var isLandscape: Bool {
        traitCollection.verticalSizeClass == .compact
    }

    private func currentMetrics() -> KeyboardMetrics {
        isLandscape ? .landscape : .portrait
    }

    private var candidateBarHeight: CGFloat {
        if isSecureContext { return 0 }
        return isLandscape ? Constants.candidateBarHeightLandscape : Constants.candidateBarHeightPortrait
    }

    private func preferredHeight() -> CGFloat {
        candidateBarHeight + currentMetrics().totalHeight(rowCount: keyboardView.layoutModel.rows.count)
    }

    private func applyMetrics() {
        keyboardView.metrics = currentMetrics()
        keyboardView.showsKeyPopups = !isLandscape
        candidateBarHeightConstraint?.constant = candidateBarHeight
        heightConstraint?.constant = preferredHeight()
    }

    private func applyLayout() {
        keyboardView.layoutModel = .make(language: inputLanguage, page: page, showsGlobe: showsGlobe)
        keyboardView.languageToggleTitle = inputLanguage == .korean ? "한" : "A"
        keyboardView.spaceTitle = inputLanguage == .korean ? String(localized: "스페이스") : "space"
        keyboardView.shiftState = page == .letters ? shift.state : .off
    }

    /// 마지막으로 반영한 보안 입력창 상태. 바뀌었을 때만 높이를 다시 계산한다.
    private var appliedSecureState: Bool?

    private func updateSecureState() {
        let secure = isSecureContext
        guard secure != appliedSecureState else { return }
        appliedSecureState = secure
        candidateBar.isHidden = secure
        if secure {
            coordinator.clear()
        }
        applyMetrics()
    }

    private func updateAppearance() {
        let style: UIUserInterfaceStyle
        if settings.followsSystemAppearance {
            let hostIsDark = textDocumentProxy.keyboardAppearance == .dark
            style = hostIsDark ? .dark : traitCollection.userInterfaceStyle
        } else {
            style = .light
        }
        view.overrideUserInterfaceStyle = style
    }

    private func updateReturnKey() {
        let proxy = textDocumentProxy
        var appearance: ReturnKeyAppearance
        switch proxy.returnKeyType ?? .default {
        case .go: appearance = .init(title: String(localized: "이동"), symbolName: nil, isAccent: true, isEnabled: true)
        case .google, .yahoo, .search:
            appearance = .init(title: String(localized: "검색"), symbolName: nil, isAccent: true, isEnabled: true)
        case .join: appearance = .init(title: String(localized: "가입"), symbolName: nil, isAccent: true, isEnabled: true)
        case .next: appearance = .init(title: String(localized: "다음"), symbolName: nil, isAccent: false, isEnabled: true)
        case .route: appearance = .init(title: String(localized: "경로"), symbolName: nil, isAccent: true, isEnabled: true)
        case .send: appearance = .init(title: String(localized: "보내기"), symbolName: nil, isAccent: true, isEnabled: true)
        case .done: appearance = .init(title: String(localized: "완료"), symbolName: nil, isAccent: true, isEnabled: true)
        case .emergencyCall:
            appearance = .init(title: String(localized: "긴급통화"), symbolName: nil, isAccent: true, isEnabled: true)
        case .continue: appearance = .init(title: String(localized: "계속"), symbolName: nil, isAccent: true, isEnabled: true)
        case .default: appearance = .default
        @unknown default: appearance = .default
        }
        if proxy.enablesReturnKeyAutomatically == true {
            appearance.isEnabled = proxy.hasText
        }
        keyboardView.returnKeyAppearance = appearance
    }

    private func updateAutoCapitalization() {
        // 한국어 자판에는 자동 대문자가 없다. Shift는 쌍자음 입력용으로만 쓴다.
        guard page == .letters, inputLanguage == .english else { return }
        let mode: AutoCapitalizationMode
        switch textDocumentProxy.autocapitalizationType ?? .sentences {
        case .none: mode = .none
        case .words: mode = .words
        case .sentences: mode = .sentences
        case .allCharacters: mode = .allCharacters
        @unknown default: mode = .sentences
        }
        let should = AutoCapitalization.shouldCapitalize(
            mode: mode,
            contextBefore: textDocumentProxy.documentContextBeforeInput
        )
        shift.applyAutoCapitalization(should)
        keyboardView.shiftState = shift.state
    }

    // MARK: - Translation
    //
    // 번역 요청 흐름:
    //   커서 앞 텍스트 ─▶ SourceTextExtractor(마지막 단어·언어 감지)
    //                 ─▶ settings.targets(for:)(켜 둔 언어만)
    //                 ─▶ TranslationCoordinator.update(디바운스 · 캐시 · 번역)
    //                 ─▶ onChange ─▶ renderCandidateBar ─▶ CandidateBarView

    /// 편집이 끝날 때마다 호출된다. 비밀번호 입력창이거나 방금 칩으로 넣은 직후면 번역하지 않는다.
    private func scheduleTranslation() {
        guard !isSecureContext, !suppressTranslation else { return }
        let source = SourceTextExtractor.extract(
            from: textDocumentProxy.documentContextBeforeInput,
            scope: settings.sourceScope
        )
        let targets = source.map { settings.targets(for: $0.language) } ?? []
        coordinator.update(source: source, targets: targets)
    }

    private func renderCandidateBar(_ state: TranslationCoordinator.BarState) {
        candidateBar.render(state, idleMessage: String(localized: "단어를 입력하면 번역돼요"))
    }

    /// 칩 탭: 원문을 번역문으로 교체(또는 뒤에 추가)하고 클립보드에 복사한다.
    private func insertTranslation(_ translation: String, chip: CandidateChipView) {
        guard case .active(let source, _) = coordinator.state else { return }
        // 1) 조합 중인 한글을 확정한다(그래야 원문 글자 수와 문서가 일치한다).
        commitComposition()

        // 2) 설정에 따라 원문을 지우고 번역문으로 바꾸거나, 원문 뒤에 붙인다.
        let proxy = textDocumentProxy
        switch settings.tapAction {
        case .replace:
            for _ in 0..<source.deleteCount {
                proxy.deleteBackward()
            }
            var text = translation + source.trailingWhitespace
            if settings.autoSpaceAfterInsert, source.trailingWhitespace.isEmpty {
                text += " "
            }
            proxy.insertText(text)
        case .append:
            let needsSpace = source.trailingWhitespace.isEmpty
            var text = (needsSpace ? " " : "") + translation
            if settings.autoSpaceAfterInsert {
                text += " "
            }
            proxy.insertText(text)
        }

        // 3) 클립보드 복사(전체 접근이 있을 때만) → 4) 체크 애니메이션·햅틱·토스트로 결과를 알린다.
        let copied = copyToPasteboard(translation)
        chip.playCheckAnimation()
        if hasFullAccess, settings.hapticsEnabled {
            UINotificationFeedbackGenerator(view: view).notificationOccurred(.success)
        }
        if copied {
            candidateBar.showToast(String(localized: "복사됨"))
        } else if !sharedDefaults.bool(forKey: Constants.fullAccessHintKey) {
            sharedDefaults.set(true, forKey: Constants.fullAccessHintKey)
            candidateBar.showToast(String(localized: "전체 접근을 켜면 복사도 돼요"), duration: .seconds(2))
        }

        // 5) 방금 넣은 번역문("apple")이 다시 번역되지 않도록, 다음 키 입력 전까지 번역을 멈춘다.
        suppressTranslation = true
        coordinator.clear()
        lastSpaceTime = nil
        updateAutoCapitalization()
        updateReturnKey()
    }

    /// 전체 접근이 없으면 클립보드에 쓸 수 없으므로 건너뛴다.
    private func copyToPasteboard(_ text: String) -> Bool {
        guard hasFullAccess else { return false }
        UIPasteboard.general.string = text
        return true
    }

    // MARK: - Hangul composition
    //
    // 한글 조합 방식: 조합 중인 음절을 문서에 실제 글자로 넣어 두고, 자모가 들어올 때마다
    // 방금 넣은 글자를 지우고 새 글자로 다시 쓴다. (서드파티 키보드는 밑줄 표시되는
    // "조합 중 상태"를 앱마다 안정적으로 쓸 수 없어서, 국내 키보드들이 쓰는 방식을 따른다.)
    //
    //   ㅅ 입력 → "ㅅ" 넣기
    //   ㅏ 입력 → "ㅅ" 지우고 "사" 넣기
    //   ㄱ 입력 → "사" 지우고 "삭" 넣기
    //   ㅗ 입력 → "삭" 지우고 "사고" 넣기   ← 받침 ㄱ이 다음 음절 초성으로 넘어감(연음)
    //   ㅏ 입력 → "고" 지우고 "과" 넣기     ← ㅗ+ㅏ = ㅘ (이중모음)
    //
    // composingInDocument: 지금 문서에 그려져 있는 "조합 중" 글자. 다음에 지울 대상이다.

    /// 조합기 상태가 바뀐 뒤, 문서에 그려진 조합 글자를 새 상태로 바꿔 그린다.
    private func renderComposition(committed: String) {
        for _ in 0..<composingInDocument.count {
            textDocumentProxy.deleteBackward()
        }
        let newComposing = composer.composing
        let text = committed + newComposing
        if !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
        composingInDocument = newComposing
    }

    /// 조합을 확정한다. 글자는 이미 문서에 있으므로 상태만 비운다.
    private func commitComposition() {
        composer.commit()
        composingInDocument = ""
    }

    private func resetComposition() {
        composer.reset()
        composingInDocument = ""
    }

    /// 사용자가 커서를 옮기거나 호스트가 텍스트를 바꾸면 조합 상태가 문서와 어긋난다. 그때는 조합을 끝낸다.
    private func syncCompositionWithDocument() {
        guard !composingInDocument.isEmpty else { return }
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        if !context.hasSuffix(composingInDocument) {
            resetComposition()
        }
    }

    // MARK: - Text editing

    /// 문자 키 입력. 한국어 자모면 조합기로, 그 밖(영문·숫자·기호)이면 바로 입력한다.
    private func insertCharacter(_ key: Key) {
        let uppercase = page == .letters && shift.isUppercase
        guard let text = key.insertedText(uppercased: uppercase) else { return }
        suppressTranslation = false

        if inputLanguage == .korean, page == .letters, let jamo = text.first, text.count == 1,
           HangulComposer.isJamo(jamo) {
            let committed = composer.input(jamo)
            renderComposition(committed: committed)
            if shift.state == .once {
                shift.didInsertCharacter()
                keyboardView.shiftState = shift.state
            }
        } else {
            commitComposition()
            textDocumentProxy.insertText(text)
            shift.didInsertCharacter()
            keyboardView.shiftState = page == .letters ? shift.state : .off
            // 숫자 페이지에서 아포스트로피를 입력하면 시스템 키보드처럼 문자 페이지로 돌아간다.
            if page != .letters, text == "'" {
                switchPage(to: .letters)
            }
        }
        lastSpaceTime = nil
        afterEdit()
    }

    private func insertSpace() {
        commitComposition()
        suppressTranslation = false
        let now = ProcessInfo.processInfo.systemUptime
        defer { afterEdit() }

        // 스페이스 두 번: "단어 " → "단어. "
        if let last = lastSpaceTime, now - last <= Constants.doubleSpaceInterval,
           let context = textDocumentProxy.documentContextBeforeInput,
           context.hasSuffix(" "),
           let beforeSpace = context.dropLast().last,
           beforeSpace.isLetter || beforeSpace.isNumber {
            textDocumentProxy.deleteBackward()
            textDocumentProxy.insertText(". ")
            lastSpaceTime = nil
            return
        }

        textDocumentProxy.insertText(" ")
        lastSpaceTime = now
        if page != .letters {
            switchPage(to: .letters)
        }
    }

    private func insertReturn() {
        commitComposition()
        textDocumentProxy.insertText("\n")
        lastSpaceTime = nil
        afterEdit()
    }

    /// 백스페이스 한 번. 조합 중이면 자모 하나만 지우고("닭" → "달"), 아니면 글자 하나를 지운다.
    private func deleteBackwardOnce() {
        suppressTranslation = false
        if composer.isComposing {
            composer.backspace()
            renderComposition(committed: "")
        } else {
            textDocumentProxy.deleteBackward()
        }
        lastSpaceTime = nil
        afterEdit()
    }

    /// 입력·삭제 직후. 다음 키의 대소문자에 영향을 주는 자동 대문자만 즉시 처리하고 나머지는 미룬다.
    private func afterEdit() {
        updateAutoCapitalization()
        scheduleDeferredUpdates()
    }

    /// 백스페이스를 누르고 있으면 0.45초 뒤부터 반복 삭제하고, 15번 이후에는 더 빨리 지운다.
    /// 손을 떼면 `stopBackspaceRepeat()`가 Task를 취소해 멈춘다.
    private func startBackspaceRepeat() {
        deleteBackwardOnce()
        backspaceTask?.cancel()
        backspaceTask = Task { [weak self] in
            try? await Task.sleep(for: Constants.backspaceInitialDelay)
            var count = 0
            while !Task.isCancelled {
                guard let self else { return }
                self.deleteBackwardOnce()
                self.feedback.keyDown(withHaptic: false)
                count += 1
                let interval = count > Constants.backspaceAccelerateAfter
                    ? Constants.backspaceFastInterval
                    : Constants.backspaceSlowInterval
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func stopBackspaceRepeat() {
        backspaceTask?.cancel()
        backspaceTask = nil
    }

    private func switchPage(to newPage: KeyboardPage) {
        guard newPage != page else { return }
        commitComposition()
        page = newPage
        applyLayout()
        if newPage == .letters {
            updateAutoCapitalization()
        }
    }

    private func toggleInputLanguage() {
        commitComposition()
        inputLanguage = inputLanguage.toggled
        sharedDefaults.set(inputLanguage.rawValue, forKey: Constants.inputLanguageKey)
        page = .letters
        shift.applyAutoCapitalization(false)
        applyLayout()
        updateAutoCapitalization()
    }
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboardView(_ view: KeyboardView, didTouchDown key: Key) {
        feedback.keyDown()
    }

    /// 키 종류에 따라 처리 함수로 나눠 보낸다.
    func keyboardView(_ view: KeyboardView, didTap key: Key) {
        switch key.action {
        case .character:
            insertCharacter(key)
        case .space:
            insertSpace()
        case .returnKey:
            insertReturn()
        case .shift:
            shift.tap(at: ProcessInfo.processInfo.systemUptime)
            keyboardView.shiftState = shift.state
        case .page(let newPage):
            switchPage(to: newPage)
        case .languageToggle:
            toggleInputLanguage()
        case .backspace, .globe:
            // 백스페이스와 지구본은 별도 경로로 처리한다.
            break
        }
    }

    func keyboardViewDidBeginBackspace(_ view: KeyboardView) {
        startBackspaceRepeat()
    }

    func keyboardViewDidEndBackspace(_ view: KeyboardView) {
        stopBackspaceRepeat()
    }

    func keyboardView(_ view: KeyboardView, didCreateGlobeButton button: UIControl) {
        // Apple 권장 방식: 탭은 다음 키보드, 길게 누르면 입력 모드 목록.
        button.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
    }
}

// MARK: - CandidateBarViewDelegate

extension KeyboardViewController: CandidateBarViewDelegate {
    func candidateBar(_ bar: CandidateBarView, didSelect text: String, language: Language, chip: CandidateChipView) {
        insertTranslation(text, chip: chip)
    }

    func candidateBarDidRequestRetry(_ bar: CandidateBarView) {
        coordinator.retry()
    }

    /// 자판 자리를 덮는 번역 언어 패널을 연다. 언어 팩이 설치된 언어만 보여준다.
    func candidateBarDidTapLanguageButton(_ bar: CandidateBarView) {
        guard languagePicker == nil else { return }
        commitComposition()
        let picker = LanguagePickerView(selection: settings.orderedTargets)
        picker.delegate = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: keyboardView.topAnchor),
            picker.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
            picker.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor)
        ])
        keyboardView.isHidden = true
        languagePicker = picker
        picker.showLoading()
        Task { [weak picker] in
            #if targetEnvironment(simulator)
            let installed: [Language] = [.english, .japanese, .spanish]  // 데모 사전 언어
            #else
            let installed = await AppleOnDeviceProvider.installedTargets()
            #endif
            picker?.show(installed: installed)
        }
    }
}

// MARK: - LanguagePickerViewDelegate

extension KeyboardViewController: LanguagePickerViewDelegate {
    /// 고른 언어를 키보드에 저장하고(설정 공유가 되면 앱 설정에도 반영) 번역을 다시 요청한다.
    func languagePicker(_ picker: LanguagePickerView, didFinishWith selection: [Language]) {
        picker.removeFromSuperview()
        languagePicker = nil
        keyboardView.isHidden = false
        guard !selection.isEmpty else { return }
        settings.enabledTargets = Set(selection)
        sharedDefaults.set(selection.map(\.code), forKey: Constants.keyboardTargetsKey)
        if AppGroup.isAvailable {
            settingsStore.save(settings)
        }
        scheduleTranslation()
    }
}
