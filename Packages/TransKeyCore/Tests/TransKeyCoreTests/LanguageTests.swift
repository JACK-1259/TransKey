import XCTest
@testable import TransKeyCore

final class LanguageTests: XCTestCase {
    func testEncodesAsPlainString() throws {
        // 예전 enum 시절 저장 형식("en")과 호환돼야 한다.
        let data = try JSONEncoder().encode(Set([Language.english]))
        XCTAssertEqual(String(data: data, encoding: .utf8), #"["en"]"#)
        let decoded = try JSONDecoder().decode([Language].self, from: Data(#"["ja","zh-TW"]"#.utf8))
        XCTAssertEqual(decoded, [.japanese, Language("zh-TW")])
    }

    func testFlags() {
        XCTAssertEqual(Language.english.flag, "🇺🇸")
        XCTAssertEqual(Language.japanese.flag, "🇯🇵")
        XCTAssertEqual(Language("zh-TW").flag, "🇹🇼")
        XCTAssertEqual(Language("zh").flag, "🇨🇳")
        XCTAssertEqual(Language("fr").flag, "🇫🇷")
    }

    func testShortLabel() {
        XCTAssertEqual(Language.english.shortLabel, "EN")
        XCTAssertEqual(Language("zh-TW").shortLabel, "ZH")
        XCTAssertEqual(Language("ar-AE").shortLabel, "AR")
    }

    func testInitFromLocaleLanguageUsesMinimalIdentifier() {
        XCTAssertEqual(Language(Locale.Language(identifier: "ja-Jpan-JP")), .japanese)
    }

    func testDisplayName() {
        XCTAssertEqual(Language.japanese.displayName(in: Locale(identifier: "ko")), "일본어")
        XCTAssertEqual(Language.english.displayName(in: Locale(identifier: "ko")), "영어")
    }

    func testDisplayOrderPutsCommonLanguagesFirst() {
        let sorted = [Language("fr"), .japanese, Language("xx"), .english].sorted(by: Language.displayOrder)
        XCTAssertEqual(sorted, [.english, .japanese, Language("fr"), Language("xx")])
    }

    func testMaxEnabledTargets() {
        var settings = TransKeySettings(enabledTargets: [.english, .japanese])
        XCTAssertTrue(settings.canEnableMoreTargets)
        settings.enabledTargets.insert(Language("fr"))
        XCTAssertFalse(settings.canEnableMoreTargets)
    }

    func testOrderedTargetsSupportsNewLanguages() {
        let settings = TransKeySettings(enabledTargets: [Language("fr"), .english, Language("zh-TW")])
        XCTAssertEqual(settings.orderedTargets, [.english, Language("zh-TW"), Language("fr")])
        XCTAssertEqual(settings.targets(for: .korean), [.english, Language("zh-TW"), Language("fr")])
    }
}
