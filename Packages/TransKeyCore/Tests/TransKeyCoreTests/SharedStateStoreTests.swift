import XCTest
@testable import TransKeyCore

final class SharedStateStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        suiteName = "SharedStateStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testKeyboardStatusRoundTrip() {
        let store = SharedStateStore(defaults: defaults)
        XCTAssertNil(store.keyboardStatus)
        let status = KeyboardStatus(lastActiveAt: Date(timeIntervalSince1970: 100), hasFullAccess: true)
        store.keyboardStatus = status
        XCTAssertEqual(store.keyboardStatus, status)
        store.keyboardStatus = nil
        XCTAssertNil(store.keyboardStatus)
    }

    func testCacheResetChangesToken() {
        let store = SharedStateStore(defaults: defaults)
        store.requestCacheReset()
        let first = store.cacheResetToken
        store.requestCacheReset()
        XCTAssertNotNil(first)
        XCTAssertNotEqual(first, store.cacheResetToken)
    }

    func testOnboardingFlag() {
        let store = SharedStateStore(defaults: defaults)
        XCTAssertFalse(store.onboardingCompleted)
        store.onboardingCompleted = true
        XCTAssertTrue(store.onboardingCompleted)
    }
}
