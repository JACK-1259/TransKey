import XCTest
@testable import TransKeyCore

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "TransKeyCoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testLoadReturnsDefaultWhenEmpty() {
        let store = UserDefaultsSettingsStore(defaults: defaults)
        XCTAssertEqual(store.load(), .default)
    }

    func testSaveAndLoadRoundTrip() {
        let store = UserDefaultsSettingsStore(defaults: defaults)
        var settings = TransKeySettings.default
        settings.enabledTargets = [.japanese]
        settings.sourceScope = .lastSentence
        settings.tapAction = .append
        settings.hapticsEnabled = false
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func testMissingKeysFallBackToDefaults() throws {
        let partial = #"{"hapticsEnabled": false}"#
        let data = try XCTUnwrap(partial.data(using: .utf8))
        defaults.set(data, forKey: UserDefaultsSettingsStore.storageKey)
        let loaded = UserDefaultsSettingsStore(defaults: defaults).load()
        XCTAssertFalse(loaded.hapticsEnabled)
        XCTAssertEqual(loaded.tapAction, .replace)
        XCTAssertEqual(loaded.enabledTargets, Set(Language.defaultTargets))
    }

    func testCorruptedDataFallsBackToDefault() throws {
        let data = try XCTUnwrap("not json".data(using: .utf8))
        defaults.set(data, forKey: UserDefaultsSettingsStore.storageKey)
        XCTAssertEqual(UserDefaultsSettingsStore(defaults: defaults).load(), .default)
    }

    func testOrderedTargetsKeepChipOrder() {
        let settings = TransKeySettings(enabledTargets: [.spanish, .english])
        XCTAssertEqual(settings.orderedTargets, [.english, .spanish])
    }

    func testDefaultTargetsAreEnglishAndJapanese() {
        XCTAssertEqual(TransKeySettings.default.orderedTargets, [.english, .japanese])
    }

    func testTargetsForKoreanSource() {
        XCTAssertEqual(TransKeySettings.default.targets(for: .korean), [.english, .japanese])
    }

    func testTargetsForEnglishSourceWithAutoDetect() {
        XCTAssertEqual(TransKeySettings.default.targets(for: .english), [.korean, .japanese])
    }

    func testTargetsForEnglishSourceWithoutAutoDetect() {
        var settings = TransKeySettings.default
        settings.autoDetectSourceLanguage = false
        XCTAssertEqual(settings.targets(for: .english), [.japanese])
    }

    func testInMemoryStore() {
        let store = InMemorySettingsStore()
        var settings = store.load()
        settings.keySoundEnabled = false
        store.save(settings)
        XCTAssertFalse(store.load().keySoundEnabled)
    }
}
