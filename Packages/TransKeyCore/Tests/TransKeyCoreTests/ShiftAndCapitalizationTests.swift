import XCTest
@testable import TransKeyCore

final class ShiftStateMachineTests: XCTestCase {
    func testSingleTapTogglesOnce() {
        var shift = ShiftStateMachine()
        shift.tap(at: 0)
        XCTAssertEqual(shift.state, .once)
        shift.tap(at: 1)
        XCTAssertEqual(shift.state, .off)
    }

    func testDoubleTapLocks() {
        var shift = ShiftStateMachine()
        shift.tap(at: 0)
        shift.tap(at: 0.2)
        XCTAssertEqual(shift.state, .locked)
    }

    func testSlowSecondTapDoesNotLock() {
        var shift = ShiftStateMachine()
        shift.tap(at: 0)
        shift.tap(at: 0.5)
        XCTAssertEqual(shift.state, .off)
    }

    func testTapWhileLockedTurnsOff() {
        var shift = ShiftStateMachine(state: .locked)
        shift.tap(at: 0)
        XCTAssertEqual(shift.state, .off)
    }

    func testOnceResetsAfterCharacter() {
        var shift = ShiftStateMachine(state: .once)
        shift.didInsertCharacter()
        XCTAssertEqual(shift.state, .off)
    }

    func testLockedSurvivesCharacters() {
        var shift = ShiftStateMachine(state: .locked)
        shift.didInsertCharacter()
        XCTAssertEqual(shift.state, .locked)
        XCTAssertTrue(shift.isUppercase)
    }

    func testAutoCapitalizationDoesNotOverrideLock() {
        var shift = ShiftStateMachine(state: .locked)
        shift.applyAutoCapitalization(false)
        XCTAssertEqual(shift.state, .locked)
    }

    func testAutoCapitalizationSetsOnceOrOff() {
        var shift = ShiftStateMachine()
        shift.applyAutoCapitalization(true)
        XCTAssertEqual(shift.state, .once)
        shift.applyAutoCapitalization(false)
        XCTAssertEqual(shift.state, .off)
    }
}

final class AutoCapitalizationTests: XCTestCase {
    func testSentencesAtDocumentStart() {
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(mode: .sentences, contextBefore: nil))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(mode: .sentences, contextBefore: ""))
    }

    func testSentencesAfterTerminator() {
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(mode: .sentences, contextBefore: "Hi. "))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(mode: .sentences, contextBefore: "Really?  "))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(mode: .sentences, contextBefore: "line\n"))
    }

    func testSentencesMidSentence() {
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(mode: .sentences, contextBefore: "Hello "))
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(mode: .sentences, contextBefore: "Hi."))
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(mode: .sentences, contextBefore: "Hel"))
    }

    func testWords() {
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(mode: .words, contextBefore: "New "))
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(mode: .words, contextBefore: "New"))
    }

    func testNoneAndAll() {
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(mode: .none, contextBefore: nil))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(mode: .allCharacters, contextBefore: "abc"))
    }
}
