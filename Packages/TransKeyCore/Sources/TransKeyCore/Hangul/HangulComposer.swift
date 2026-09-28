import Foundation

/// 두벌식 한글 조합기.
///
/// ## 한글 음절의 구조
/// 한글 음절은 초성(첫 자음) + 중성(모음) + 종성(받침, 없을 수도 있음)으로 이루어진다.
/// 유니코드는 11,172개 음절을 순서대로 배치해 두었기 때문에 계산으로 만들 수 있다.
///
///     음절 코드 = 0xAC00 + (초성 번호 × 21 + 중성 번호) × 28 + 종성 번호
///     예) "각" = 0xAC00 + (0[ㄱ] × 21 + 0[ㅏ]) × 28 + 1[ㄱ] = 0xAC01
///
/// ## 조합 규칙(오토마타)
/// - 자음 입력
///   - 비어 있으면 → 초성
///   - 초성+중성 뒤면 → 받침(단, ㄸ·ㅃ·ㅉ은 받침이 될 수 없어 새 음절)
///   - 받침 뒤면 → 겹받침이 되면 합치고(ㄱ+ㅅ=ㄳ), 아니면 새 음절
/// - 모음 입력
///   - 초성 뒤면 → 중성
///   - 중성 뒤면 → 이중모음이 되면 합치고(ㅗ+ㅏ=ㅘ), 아니면 새 음절
///   - 받침 뒤면 → **연음**: 받침(겹받침이면 뒤쪽 자음)을 떼어 다음 음절의 초성으로 옮긴다
///     예) "닭" + ㅏ → "달" + "가"
///
/// ## 백스페이스
/// 입력할 때마다 직전 상태를 `history`에 쌓아 두고, 백스페이스 때 하나씩 꺼낸다.
/// 그래서 "닭" → "달" → "다" → "ㄷ" → "" 처럼 자모 단위로 지워진다.
///
/// 입력은 호환 자모(ㄱ, ㅏ …)로 받는다. `input(_:)`은 확정된 텍스트를 반환하고,
/// 아직 조합 중인 글자는 `composing`으로 노출한다. 키보드는 문서에 `composing`을 그려 두고
/// 상태가 바뀔 때마다 이전 조합 글자를 지우고 새로 그린다.
public struct HangulComposer: Equatable, Sendable {
    struct Syllable: Equatable, Sendable {
        var initial: Character?
        var medial: Character?
        var final: Character?

        var isEmpty: Bool { initial == nil && medial == nil && final == nil }
    }

    private var current = Syllable()
    /// 현재 음절을 만들어 온 중간 상태들. 백스페이스 시 자모 단위로 되돌린다.
    private var history: [Syllable] = []

    public init() {}

    public var isComposing: Bool { !current.isEmpty }

    /// 현재 조합 중인 글자(없으면 빈 문자열).
    public var composing: String { Self.render(current) }

    public static func isJamo(_ character: Character) -> Bool {
        HangulTables.isConsonant(character) || HangulTables.isVowel(character)
    }

    /// 자모 하나를 입력한다. 반환값은 이번 입력으로 확정된 텍스트다.
    @discardableResult
    public mutating func input(_ jamo: Character) -> String {
        if HangulTables.isVowel(jamo) {
            return inputVowel(jamo)
        }
        if HangulTables.isConsonant(jamo) {
            return inputConsonant(jamo)
        }
        // 자모가 아니면 조합을 끝내고 그대로 확정한다.
        return commit() + String(jamo)
    }

    /// 조합 중인 글자를 자모 하나만큼 되돌린다. 조합 중이 아니면 false.
    @discardableResult
    public mutating func backspace() -> Bool {
        guard isComposing else { return false }
        if let previous = history.popLast() {
            current = previous
        } else {
            current = Syllable()
        }
        return true
    }

    /// 조합을 끝낸다. 확정된 글자를 반환한다(문서에는 이미 그려져 있다).
    @discardableResult
    public mutating func commit() -> String {
        let text = composing
        reset()
        return text
    }

    public mutating func reset() {
        current = Syllable()
        history = []
    }

    // MARK: - Private

    private mutating func push(_ next: Syllable) {
        history.append(current)
        current = next
    }

    private mutating func startNew(_ syllable: Syllable, historyPrefix: [Syllable] = []) -> String {
        let committed = Self.render(current)
        history = historyPrefix
        current = syllable
        return committed
    }

    /// 자음 입력 처리. (초성, 중성, 종성)이 각각 있는지에 따라 분기한다.
    private mutating func inputConsonant(_ jamo: Character) -> String {
        switch (current.initial, current.medial, current.final) {
        case (nil, nil, nil):
            push(Syllable(initial: jamo))
            return ""
        case (_, .some, nil) where current.initial != nil:
            // 초성+중성: 받침으로 쓸 수 있으면 받침, 아니면(ㄸ, ㅃ, ㅉ) 새 음절.
            if HangulTables.finalIndex(of: jamo) != nil {
                var next = current
                next.final = jamo
                push(next)
                return ""
            }
            return startNew(Syllable(initial: jamo), historyPrefix: [Syllable()])
        case (.some, .some, .some(let final)):
            if let combined = HangulTables.combineFinals(final, jamo) {
                var next = current
                next.final = combined
                push(next)
                return ""
            }
            return startNew(Syllable(initial: jamo), historyPrefix: [Syllable()])
        default:
            // 초성만 있거나 모음만 있는 상태: 확정하고 새 음절 시작.
            return startNew(Syllable(initial: jamo), historyPrefix: [Syllable()])
        }
    }

    /// 모음 입력 처리. 받침이 있는 음절 뒤에 모음이 오면 연음 규칙을 적용한다.
    private mutating func inputVowel(_ jamo: Character) -> String {
        switch (current.initial, current.medial, current.final) {
        case (nil, nil, nil):
            push(Syllable(medial: jamo))
            return ""
        case (.some, nil, nil):
            var next = current
            next.medial = jamo
            push(next)
            return ""
        case (_, .some(let medial), nil):
            if let combined = HangulTables.combineVowels(medial, jamo) {
                var next = current
                next.medial = combined
                push(next)
                return ""
            }
            return startNew(Syllable(medial: jamo), historyPrefix: [Syllable()])
        case (.some(let initial), .some(let medial), .some(let final)):
            // 연음: 받침(겹받침이면 뒤쪽 자음)을 다음 음절의 초성으로 넘긴다.
            let kept: Character?
            let moved: Character
            if let split = HangulTables.splitFinal(final) {
                kept = split.first
                moved = split.second
            } else {
                kept = nil
                moved = final
            }
            current = Syllable(initial: initial, medial: medial, final: kept)
            let movedInitial = Syllable(initial: moved)
            return startNew(
                Syllable(initial: moved, medial: jamo),
                historyPrefix: [Syllable(), movedInitial]
            )
        default:
            return startNew(Syllable(medial: jamo), historyPrefix: [Syllable()])
        }
    }

    /// 조합 상태를 실제 글자로 바꾼다. 초성+중성이 있으면 위의 공식으로 완성형 음절을 계산하고,
    /// 자음이나 모음 하나만 있으면 그 자모를 그대로 보여준다.
    static func render(_ syllable: Syllable) -> String {
        switch (syllable.initial, syllable.medial, syllable.final) {
        case (nil, nil, nil):
            return ""
        case (.some(let initial), nil, nil):
            return String(initial)
        case (nil, .some(let medial), nil):
            return String(medial)
        case (.some(let initial), .some(let medial), let final):
            guard let l = HangulTables.initialIndex(of: initial),
                  let v = HangulTables.medialIndex(of: medial) else {
                return String(initial) + String(medial)
            }
            let t = final.flatMap(HangulTables.finalIndex(of:)) ?? 0
            let scalarValue = 0xAC00 + (l * 21 + v) * 28 + t
            guard let scalar = Unicode.Scalar(scalarValue) else { return "" }
            return String(Character(scalar))
        default:
            // 받침만 남는 상태는 만들어지지 않지만, 방어적으로 자모를 이어 붙인다.
            return [syllable.initial, syllable.medial, syllable.final]
                .compactMap { $0 }
                .map(String.init)
                .joined()
        }
    }
}

/// 두벌식 자모 표와 결합 규칙.
enum HangulTables {
    static let initials: [Character] = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
        "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]

    static let medials: [Character] = [
        "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ", "ㅙ",
        "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"
    ]

    /// 인덱스 0은 받침 없음.
    static let finals: [Character?] = [
        nil, "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ",
        "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]

    private static let vowelPairs: [String: Character] = [
        "ㅗㅏ": "ㅘ", "ㅗㅐ": "ㅙ", "ㅗㅣ": "ㅚ",
        "ㅜㅓ": "ㅝ", "ㅜㅔ": "ㅞ", "ㅜㅣ": "ㅟ",
        "ㅡㅣ": "ㅢ"
    ]

    private static let finalPairs: [String: Character] = [
        "ㄱㅅ": "ㄳ", "ㄴㅈ": "ㄵ", "ㄴㅎ": "ㄶ",
        "ㄹㄱ": "ㄺ", "ㄹㅁ": "ㄻ", "ㄹㅂ": "ㄼ", "ㄹㅅ": "ㄽ",
        "ㄹㅌ": "ㄾ", "ㄹㅍ": "ㄿ", "ㄹㅎ": "ㅀ", "ㅂㅅ": "ㅄ"
    ]

    private static let finalSplits: [Character: (first: Character, second: Character)] = {
        var result: [Character: (Character, Character)] = [:]
        for (pair, combined) in finalPairs {
            let chars = Array(pair)
            result[combined] = (chars[0], chars[1])
        }
        return result
    }()

    static func isConsonant(_ c: Character) -> Bool { initials.contains(c) }
    static func isVowel(_ c: Character) -> Bool { medials.contains(c) }

    static func initialIndex(of c: Character) -> Int? { initials.firstIndex(of: c) }
    static func medialIndex(of c: Character) -> Int? { medials.firstIndex(of: c) }
    static func finalIndex(of c: Character) -> Int? {
        finals.firstIndex { $0 == c }
    }

    static func combineVowels(_ a: Character, _ b: Character) -> Character? {
        vowelPairs[String([a, b])]
    }

    static func combineFinals(_ a: Character, _ b: Character) -> Character? {
        finalPairs[String([a, b])]
    }

    static func splitFinal(_ c: Character) -> (first: Character, second: Character)? {
        finalSplits[c]
    }
}
