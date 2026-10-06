import Foundation

/// 번역 대상 텍스트의 범위.
public enum SourceScope: String, Codable, CaseIterable, Sendable {
    /// 커서 앞 마지막 단어.
    case lastWord
    /// 커서 앞 마지막 문장 전체.
    case lastSentence
}

/// 후보 칩을 탭했을 때의 동작.
public enum ChipTapAction: String, Codable, CaseIterable, Sendable {
    /// 원문을 지우고 번역문으로 교체.
    case replace
    /// 원문 뒤에 번역문을 추가.
    case append
}

/// 번역 엔진 우선순위. 클라우드 엔진은 현재 보류 상태라 기본값은 온디바이스 우선이다.
public enum EnginePriority: String, Codable, CaseIterable, Sendable {
    case onDeviceFirst
    case cloudFirst
}

/// 컨테이너 앱과 키보드가 공유하는 사용자 설정.
public struct TransKeySettings: Codable, Equatable, Sendable {
    public var enabledTargets: Set<Language>
    public var sourceScope: SourceScope
    public var tapAction: ChipTapAction
    public var hapticsEnabled: Bool
    public var keySoundEnabled: Bool
    public var autoSpaceAfterInsert: Bool
    public var followsSystemAppearance: Bool
    public var autoDetectSourceLanguage: Bool
    public var enginePriority: EnginePriority

    public init(
        enabledTargets: Set<Language> = Set(Language.defaultTargets),
        sourceScope: SourceScope = .lastWord,
        tapAction: ChipTapAction = .replace,
        hapticsEnabled: Bool = true,
        keySoundEnabled: Bool = true,
        autoSpaceAfterInsert: Bool = false,
        followsSystemAppearance: Bool = true,
        autoDetectSourceLanguage: Bool = true,
        enginePriority: EnginePriority = .onDeviceFirst
    ) {
        self.enabledTargets = enabledTargets
        self.sourceScope = sourceScope
        self.tapAction = tapAction
        self.hapticsEnabled = hapticsEnabled
        self.keySoundEnabled = keySoundEnabled
        self.autoSpaceAfterInsert = autoSpaceAfterInsert
        self.followsSystemAppearance = followsSystemAppearance
        self.autoDetectSourceLanguage = autoDetectSourceLanguage
        self.enginePriority = enginePriority
    }

    public static let `default` = TransKeySettings()

    private enum CodingKeys: String, CodingKey {
        case enabledTargets, sourceScope, tapAction, hapticsEnabled, keySoundEnabled
        case autoSpaceAfterInsert, followsSystemAppearance, autoDetectSourceLanguage, enginePriority
    }

    /// 앱 업데이트로 새 항목이 추가돼도 기존 저장값을 잃지 않도록, 없는 키는 기본값으로 채운다.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = TransKeySettings.default
        enabledTargets = try container.decodeIfPresent(Set<Language>.self, forKey: .enabledTargets) ?? fallback.enabledTargets
        sourceScope = try container.decodeIfPresent(SourceScope.self, forKey: .sourceScope) ?? fallback.sourceScope
        tapAction = try container.decodeIfPresent(ChipTapAction.self, forKey: .tapAction) ?? fallback.tapAction
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? fallback.hapticsEnabled
        keySoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .keySoundEnabled) ?? fallback.keySoundEnabled
        autoSpaceAfterInsert = try container.decodeIfPresent(Bool.self, forKey: .autoSpaceAfterInsert) ?? fallback.autoSpaceAfterInsert
        followsSystemAppearance = try container.decodeIfPresent(Bool.self, forKey: .followsSystemAppearance) ?? fallback.followsSystemAppearance
        autoDetectSourceLanguage = try container.decodeIfPresent(Bool.self, forKey: .autoDetectSourceLanguage) ?? fallback.autoDetectSourceLanguage
        enginePriority = try container.decodeIfPresent(EnginePriority.self, forKey: .enginePriority) ?? fallback.enginePriority
    }

    /// 켜 둔 번역 언어를 표시 순서(영어, 일본어, 중국어 …)로 정렬한 목록.
    public var orderedTargets: [Language] {
        enabledTargets.sorted(by: Language.displayOrder)
    }

    /// 언어를 더 켤 수 있는지. 후보 바에는 최대 3개까지만 보여준다.
    public var canEnableMoreTargets: Bool {
        enabledTargets.count < Language.maxEnabledTargets
    }

    /// 원문 언어에 맞춘 칩 목록. 원문과 같은 언어는 빼고,
    /// 자동 감지가 켜져 있으면 한국어가 아닌 원문에 KO 칩을 맨 앞에 넣는다(예: 영어 입력 → KO, JA).
    public func targets(for source: Language) -> [Language] {
        var result = orderedTargets.filter { $0 != source }
        if autoDetectSourceLanguage, source != .korean {
            result.insert(.korean, at: 0)
        }
        return result
    }
}
