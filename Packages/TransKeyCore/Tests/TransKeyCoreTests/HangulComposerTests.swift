import XCTest
@testable import TransKeyCore

final class HangulComposerTests: XCTestCase {
    /// 자모 문자열을 차례로 입력하고 문서에 보이는 최종 텍스트(확정 + 조합 중)를 반환한다.
    private func type(_ jamos: String, composer: inout HangulComposer) -> String {
        var committed = ""
        for jamo in jamos {
            committed += composer.input(jamo)
        }
        return committed + composer.composing
    }

    private func type(_ jamos: String) -> String {
        var composer = HangulComposer()
        return type(jamos, composer: &composer)
    }

    // MARK: - 기본 음절

    func testSingleConsonant() { XCTAssertEqual(type("ㄱ"), "ㄱ") }
    func testSingleVowel() { XCTAssertEqual(type("ㅏ"), "ㅏ") }
    func testOpenSyllable() { XCTAssertEqual(type("ㄱㅏ"), "가") }
    func testClosedSyllable() { XCTAssertEqual(type("ㄱㅏㄱ"), "각") }
    func testWordSagwa() { XCTAssertEqual(type("ㅅㅏㄱㅗㅏ"), "사과") }
    func testAnnyeonghaseyo() { XCTAssertEqual(type("ㅇㅏㄴㄴㅕㅇㅎㅏㅅㅔㅇㅛ"), "안녕하세요") }
    func testDoubleInitial() { XCTAssertEqual(type("ㄲㅏ"), "까") }
    func testDoubleInitialWithFinal() { XCTAssertEqual(type("ㅃㅏㅇ"), "빵") }
    func testSsangSiotFinal() { XCTAssertEqual(type("ㅇㅣㅆ"), "있") }

    // MARK: - 겹받침

    func testGap() { XCTAssertEqual(type("ㄱㅏㅂㅅ"), "값") }
    func testDak() { XCTAssertEqual(type("ㄷㅏㄹㄱ"), "닭") }
    func testAnj() { XCTAssertEqual(type("ㅇㅏㄴㅈ"), "앉") }
    func testManh() { XCTAssertEqual(type("ㅁㅏㄴㅎ"), "많") }
    func testSalm() { XCTAssertEqual(type("ㅅㅏㄹㅁ"), "삶") }
    func testBalb() { XCTAssertEqual(type("ㅂㅏㄹㅂ"), "밟") }
    func testGols() { XCTAssertEqual(type("ㄱㅗㄹㅅ"), "곬") }
    func testHalt() { XCTAssertEqual(type("ㅎㅏㄹㅌ"), "핥") }
    func testEulp() { XCTAssertEqual(type("ㅇㅡㄹㅍ"), "읊") }
    func testSilh() { XCTAssertEqual(type("ㅅㅣㄹㅎ"), "싫") }
    func testNeoks() { XCTAssertEqual(type("ㄴㅓㄱㅅ"), "넋") }

    // MARK: - 이중모음

    func testGwa() { XCTAssertEqual(type("ㄱㅗㅏ"), "과") }
    func testWae() { XCTAssertEqual(type("ㅇㅗㅐ"), "왜") }
    func testOe() { XCTAssertEqual(type("ㅇㅗㅣ"), "외") }
    func testMwo() { XCTAssertEqual(type("ㅁㅜㅓ"), "뭐") }
    func testSwe() { XCTAssertEqual(type("ㅅㅜㅔ"), "쉐") }
    func testWi() { XCTAssertEqual(type("ㅇㅜㅣ"), "위") }
    func testUisa() { XCTAssertEqual(type("ㅇㅡㅣㅅㅏ"), "의사") }
    func testBwelk() { XCTAssertEqual(type("ㅂㅜㅔㄹㄱ"), "뷁") }
    func testStandaloneCompoundVowel() { XCTAssertEqual(type("ㅗㅏ"), "ㅘ") }

    // MARK: - 연음(받침이 다음 모음으로 넘어감)

    func testLiaisonSimpleFinal() { XCTAssertEqual(type("ㄱㅏㄱㅏ"), "가가") }
    func testIlgeoWithIeung() { XCTAssertEqual(type("ㅇㅣㄹㄱㅇㅓ"), "읽어") }
    func testIlgeoLiaison() { XCTAssertEqual(type("ㅇㅣㄹㄱㅓ"), "일거") }
    func testDakLiaison() { XCTAssertEqual(type("ㄷㅏㄹㄱㅏ"), "달가") }
    func testGapLiaison() { XCTAssertEqual(type("ㄱㅏㅂㅅㅣ"), "갑시") }
    func testManhiWithIeung() { XCTAssertEqual(type("ㅁㅏㄴㅎㅇㅣ"), "많이") }
    func testSilheo() { XCTAssertEqual(type("ㅅㅣㄹㅎㅇㅓ"), "싫어") }
    func testGwaenchanha() { XCTAssertEqual(type("ㄱㅗㅐㄴㅊㅏㄴㅎㅇㅏ"), "괜찮아") }
    func testEopda() { XCTAssertEqual(type("ㅇㅓㅂㅅㄷㅏ"), "없다") }

    // MARK: - 조합 불가 케이스

    func testTteCannotBeFinal() { XCTAssertEqual(type("ㄸㅏㄸ"), "따ㄸ") }
    func testConsonantAfterConsonant() { XCTAssertEqual(type("ㄱㄱ"), "ㄱㄱ") }
    func testVowelAfterOpenSyllable() { XCTAssertEqual(type("ㄱㅏㅏ"), "가ㅏ") }
    func testNonCombinableFinals() { XCTAssertEqual(type("ㄱㅏㄱㄴ"), "각ㄴ") }
    func testNonJamoCommits() { XCTAssertEqual(type("ㄱㅏ1"), "가1") }

    // MARK: - 백스페이스(자모 단위 해체)

    func testBackspaceDecomposesCompoundFinal() {
        var composer = HangulComposer()
        _ = type("ㄷㅏㄹㄱ", composer: &composer)
        XCTAssertEqual(composer.composing, "닭")
        composer.backspace()
        XCTAssertEqual(composer.composing, "달")
        composer.backspace()
        XCTAssertEqual(composer.composing, "다")
        composer.backspace()
        XCTAssertEqual(composer.composing, "ㄷ")
        composer.backspace()
        XCTAssertEqual(composer.composing, "")
        XCTAssertFalse(composer.isComposing)
    }

    func testBackspaceDecomposesCompoundVowel() {
        var composer = HangulComposer()
        _ = type("ㄱㅗㅏ", composer: &composer)
        composer.backspace()
        XCTAssertEqual(composer.composing, "고")
    }

    func testBackspaceUi() {
        var composer = HangulComposer()
        _ = type("ㅇㅡㅣ", composer: &composer)
        composer.backspace()
        XCTAssertEqual(composer.composing, "으")
    }

    func testBackspaceAfterLiaison() {
        var composer = HangulComposer()
        let text = type("ㄷㅏㄹㄱㅏ", composer: &composer)
        XCTAssertEqual(text, "달가")
        composer.backspace()
        XCTAssertEqual(composer.composing, "ㄱ")
        composer.backspace()
        XCTAssertEqual(composer.composing, "")
        XCTAssertFalse(composer.backspace())
    }

    func testBackspaceWhenEmptyReturnsFalse() {
        var composer = HangulComposer()
        XCTAssertFalse(composer.backspace())
    }

    func testCommitResetsState() {
        var composer = HangulComposer()
        _ = type("ㄱㅏㄱ", composer: &composer)
        XCTAssertEqual(composer.commit(), "각")
        XCTAssertFalse(composer.isComposing)
        XCTAssertEqual(type("ㅏ", composer: &composer), "ㅏ")
    }

    func testTypingContinuesAfterBackspace() {
        var composer = HangulComposer()
        _ = type("ㄱㅏㅂㅅ", composer: &composer)
        composer.backspace()
        XCTAssertEqual(composer.composing, "갑")
        XCTAssertEqual(type("ㄱ", composer: &composer), "갑ㄱ")
    }

    func testIsJamo() {
        XCTAssertTrue(HangulComposer.isJamo("ㄱ"))
        XCTAssertTrue(HangulComposer.isJamo("ㅢ"))
        XCTAssertFalse(HangulComposer.isJamo("a"))
        XCTAssertFalse(HangulComposer.isJamo("가"))
    }
}
