import XCTest
@testable import TransKeyCore

final class SourceLanguageDetectorTests: XCTestCase {
    private func detect(_ text: String) -> Language? { SourceLanguageDetector.detect(text) }

    // MARK: - 문자 종류로 바로 정하는 언어

    func testKorean() { XCTAssertEqual(detect("사과"), .korean) }
    func testKoreanMixedWithLatin() { XCTAssertEqual(detect("app사과"), .korean) }
    func testJapaneseKana() { XCTAssertEqual(detect("りんご"), .japanese) }
    func testJapaneseKanaWithKanji() { XCTAssertEqual(detect("林檎を食べる"), .japanese) }
    func testThai() { XCTAssertEqual(detect("แอปเปิ้ล"), Language("th")) }
    func testArabic() { XCTAssertEqual(detect("تفاحة"), Language("ar-AE")) }
    func testHindi() { XCTAssertEqual(detect("सेब"), Language("hi")) }

    // MARK: - 중국어 간체/번체

    func testSimplifiedChinese() { XCTAssertEqual(detect("我喜欢吃苹果"), Language("zh")) }
    func testTraditionalChinese() { XCTAssertEqual(detect("我喜歡吃蘋果"), Language("zh-TW")) }

    // MARK: - 알파벳 언어

    func testEnglishWord() { XCTAssertEqual(detect("apple"), .english) }
    func testEnglishSentence() { XCTAssertEqual(detect("I would like to eat an apple"), .english) }
    func testSpanishWord() { XCTAssertEqual(detect("manzana"), .spanish) }
    func testSpanishSentence() { XCTAssertEqual(detect("¿Dónde está la estación de tren?"), .spanish) }
    func testFrenchSentence() { XCTAssertEqual(detect("Je voudrais manger une pomme"), Language("fr")) }
    func testGermanSentence() { XCTAssertEqual(detect("Ich möchte einen Apfel essen"), Language("de")) }
    func testAmbiguousShortWordFallsBackToEnglish() { XCTAssertEqual(detect("ok"), .english) }
    func testSpanishGreeting() { XCTAssertEqual(detect("hola"), .spanish) }
    func testFrenchWord() { XCTAssertEqual(detect("bonjour"), Language("fr")) }
    func testEnglishWordsStayEnglish() {
        for word in ["hello", "water", "computer", "chat"] {
            XCTAssertEqual(detect(word), .english, word)
        }
    }

    // MARK: - 키릴 문자

    func testRussian() { XCTAssertEqual(detect("Я хочу съесть яблоко"), Language("ru")) }

    // MARK: - 번역하지 않는 입력

    func testDigitsAndSymbols() { XCTAssertNil(detect("123!")) }
    func testIncompleteJamo() { XCTAssertNil(detect("ㅅ")) }

    // MARK: - 원문 언어별 칩 구성(모든 언어에 같은 규칙)

    func testTargetsForEachSourceLanguage() {
        let settings = TransKeySettings(enabledTargets: [.english, .japanese, Language("zh")])
        XCTAssertEqual(settings.targets(for: .korean), [.english, .japanese, Language("zh")])
        XCTAssertEqual(settings.targets(for: .english), [.korean, .japanese, Language("zh")])
        XCTAssertEqual(settings.targets(for: .japanese), [.korean, .english, Language("zh")])
        XCTAssertEqual(settings.targets(for: .spanish), [.korean, .english, .japanese])
    }
}
