import XCTest
@testable import TransKeyCore

final class SourceTextExtractorTests: XCTestCase {
    func testLastWordKorean() {
        let source = SourceTextExtractor.extract(from: "나는 사과", scope: .lastWord)
        XCTAssertEqual(source?.text, "사과")
        XCTAssertEqual(source?.deleteCount, 2)
        XCTAssertEqual(source?.language, .korean)
    }

    func testTrailingSpaceIsIncludedInDeleteCount() {
        let source = SourceTextExtractor.extract(from: "사과 ", scope: .lastWord)
        XCTAssertEqual(source?.text, "사과")
        XCTAssertEqual(source?.deleteCount, 3)
        XCTAssertEqual(source?.trailingWhitespace, " ")
    }

    func testPunctuationSeparatesWords() {
        XCTAssertEqual(SourceTextExtractor.extract(from: "안녕,사과", scope: .lastWord)?.text, "사과")
    }

    func testNewlineEndsContext() {
        XCTAssertNil(SourceTextExtractor.extract(from: "사과\n", scope: .lastWord))
    }

    func testEmptyAndNil() {
        XCTAssertNil(SourceTextExtractor.extract(from: nil, scope: .lastWord))
        XCTAssertNil(SourceTextExtractor.extract(from: "", scope: .lastWord))
        XCTAssertNil(SourceTextExtractor.extract(from: "   ", scope: .lastWord))
    }

    func testIncompleteJamoIsNotTranslated() {
        XCTAssertNil(SourceTextExtractor.extract(from: "ㅅ", scope: .lastWord))
    }

    func testNumbersAreNotTranslated() {
        XCTAssertNil(SourceTextExtractor.extract(from: "2026", scope: .lastWord))
    }

    func testEnglishWord() {
        let source = SourceTextExtractor.extract(from: "I like apple", scope: .lastWord)
        XCTAssertEqual(source?.text, "apple")
        XCTAssertEqual(source?.language, .english)
    }

    func testLastSentence() {
        let source = SourceTextExtractor.extract(from: "안녕. 나는 사과를 좋아해", scope: .lastSentence)
        XCTAssertEqual(source?.text, "나는 사과를 좋아해")
        XCTAssertEqual(source?.deleteCount, 10)
    }

    func testLastSentenceIncludesTerminator() {
        let source = SourceTextExtractor.extract(from: "안녕. 반가워!", scope: .lastSentence)
        XCTAssertEqual(source?.text, "반가워!")
    }

    func testLongInputIsTruncated() {
        let long = String(repeating: "가", count: 250)
        let source = SourceTextExtractor.extract(from: long, scope: .lastWord)
        XCTAssertEqual(source?.text.count, SourceTextExtractor.maxLength)
        XCTAssertEqual(source?.deleteCount, 250)
    }

    func testLanguageDetection() {
        XCTAssertEqual(SourceLanguageDetector.detect("사과"), .korean)
        XCTAssertEqual(SourceLanguageDetector.detect("apple"), .english)
        XCTAssertEqual(SourceLanguageDetector.detect("app사과"), .korean)
        XCTAssertNil(SourceLanguageDetector.detect("123!"))
    }
}

final class LRUCacheTests: XCTestCase {
    func testEvictsLeastRecentlyUsed() {
        var cache = LRUCache<String, Int>(capacity: 2)
        cache.set(1, for: "a")
        cache.set(2, for: "b")
        _ = cache.value(for: "a")
        cache.set(3, for: "c")
        XCTAssertEqual(cache.value(for: "a"), 1)
        XCTAssertNil(cache.value(for: "b"))
        XCTAssertEqual(cache.value(for: "c"), 3)
    }

    func testUpdateExistingKeyDoesNotGrow() {
        var cache = LRUCache<String, Int>(capacity: 2)
        cache.set(1, for: "a")
        cache.set(2, for: "a")
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.value(for: "a"), 2)
    }

    func testRemoveAll() {
        var cache = LRUCache<String, Int>(capacity: 2)
        cache.set(1, for: "a")
        cache.removeAll()
        XCTAssertNil(cache.value(for: "a"))
    }
}
