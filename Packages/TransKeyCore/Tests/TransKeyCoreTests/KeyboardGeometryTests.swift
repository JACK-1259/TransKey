import XCTest
@testable import TransKeyCore

final class KeyboardGeometryTests: XCTestCase {
    /// iPhone SE(320/375), 표준(393), Pro Max(440), 가로(852~956)를 포괄한다.
    private let widths: [CGFloat] = [320, 375, 393, 402, 440, 667, 852, 956]
    private let pages: [KeyboardPage] = [.letters, .numbers, .symbols]

    func testLettersLayoutShape() {
        let layout = KeyboardLayout.english(page: .letters, showsGlobe: true)
        XCTAssertEqual(layout.rows.map(\.keys.count), [10, 9, 9, 5])
        XCTAssertEqual(layout.rows[3].keys.map(\.action),
                       [.page(.numbers), .globe, .languageToggle, .space, .returnKey])
    }

    func testGlobeOmittedWhenNotNeeded() {
        let layout = KeyboardLayout.english(page: .letters, showsGlobe: false)
        XCTAssertFalse(layout.rows.flatMap(\.keys).contains { $0.action == .globe })
    }

    func testNumbersAndSymbolsSwitchBetweenEachOther() {
        let numbers = KeyboardLayout.english(page: .numbers, showsGlobe: false)
        let symbols = KeyboardLayout.english(page: .symbols, showsGlobe: false)
        XCTAssertEqual(numbers.rows[2].keys.first?.action, .page(.symbols))
        XCTAssertEqual(symbols.rows[2].keys.first?.action, .page(.numbers))
        XCTAssertEqual(numbers.rows[3].keys.first?.action, .page(.letters))
    }

    func testFramesStayInsideBoundsAndDoNotOverlap() {
        for width in widths {
            for page in pages {
                for globe in [true, false] {
                    for metrics in [KeyboardMetrics.portrait, .landscape] {
                        let layout = KeyboardLayout.english(page: page, showsGlobe: globe)
                        let rows = KeyboardGeometry.frames(for: layout, width: width, metrics: metrics)
                        let height = metrics.totalHeight(rowCount: rows.count)
                        for row in rows {
                            for frame in row {
                                XCTAssertGreaterThan(frame.width, 0)
                                XCTAssertGreaterThanOrEqual(frame.minX, metrics.sideInset - 0.001)
                                XCTAssertLessThanOrEqual(frame.maxX, width - metrics.sideInset + 0.001)
                                XCTAssertLessThanOrEqual(frame.maxY, height + 0.001)
                            }
                            for (a, b) in zip(row, row.dropFirst()) {
                                XCTAssertLessThanOrEqual(a.maxX, b.minX + 0.001, "width \(width) page \(page)")
                            }
                        }
                    }
                }
            }
        }
    }

    func testTopRowFillsContentWidth() {
        let metrics = KeyboardMetrics.portrait
        let layout = KeyboardLayout.english(page: .letters, showsGlobe: true)
        let row = KeyboardGeometry.frames(for: layout, width: 393, metrics: metrics)[0]
        XCTAssertEqual(row.first?.minX ?? 0, metrics.sideInset, accuracy: 0.001)
        XCTAssertEqual(row.last?.maxX ?? 0, 393 - metrics.sideInset, accuracy: 0.001)
    }

    func testSecondRowIsCentered() {
        let layout = KeyboardLayout.english(page: .letters, showsGlobe: true)
        let row = KeyboardGeometry.frames(for: layout, width: 393, metrics: .portrait)[1]
        let left = (row.first?.minX ?? 0)
        let right = 393 - (row.last?.maxX ?? 0)
        XCTAssertEqual(left, right, accuracy: 0.001)
    }

    func testSpreadRowPinsShiftAndBackspaceToEdges() {
        let metrics = KeyboardMetrics.portrait
        let layout = KeyboardLayout.english(page: .letters, showsGlobe: true)
        let row = KeyboardGeometry.frames(for: layout, width: 393, metrics: metrics)[2]
        XCTAssertEqual(row.first?.minX ?? 0, metrics.sideInset, accuracy: 0.001)
        XCTAssertEqual(row.last?.maxX ?? 0, 393 - metrics.sideInset, accuracy: 0.001)
    }

    func testSpaceBarFillsRemainingWidth() {
        let metrics = KeyboardMetrics.portrait
        let layout = KeyboardLayout.english(page: .letters, showsGlobe: false)
        let row = KeyboardGeometry.frames(for: layout, width: 393, metrics: metrics)[3]
        XCTAssertEqual(row.last?.maxX ?? 0, 393 - metrics.sideInset, accuracy: 0.001)
        XCTAssertGreaterThan(row[2].width, row[0].width)
    }

    func testKoreanLayoutShape() {
        let layout = KeyboardLayout.make(language: .korean, page: .letters, showsGlobe: false)
        XCTAssertEqual(layout.rows.map(\.keys.count), [10, 9, 9, 4])
        XCTAssertEqual(layout.rows[0].keys.first?.insertedText(uppercased: false), "ㅂ")
        XCTAssertEqual(layout.rows[0].keys.first?.insertedText(uppercased: true), "ㅃ")
        XCTAssertEqual(layout.rows[0].keys[8].insertedText(uppercased: true), "ㅒ")
        // 쌍자음이 없는 키는 Shift여도 그대로다.
        XCTAssertEqual(layout.rows[1].keys.first?.insertedText(uppercased: true), "ㅁ")
    }

    func testNumberPagesIgnoreInputLanguage() {
        XCTAssertEqual(KeyboardLayout.make(language: .korean, page: .numbers, showsGlobe: true),
                       KeyboardLayout.english(page: .numbers, showsGlobe: true))
    }

    func testKoreanFramesFitAllWidths() {
        for width in widths {
            let layout = KeyboardLayout.make(language: .korean, page: .letters, showsGlobe: true)
            let rows = KeyboardGeometry.frames(for: layout, width: width, metrics: .portrait)
            for row in rows {
                for (a, b) in zip(row, row.dropFirst()) {
                    XCTAssertLessThanOrEqual(a.maxX, b.minX + 0.001)
                }
                XCTAssertLessThanOrEqual(row.last?.maxX ?? 0, width + 0.001)
            }
        }
    }

    func testTwoUnitKeyEqualsTwoKeysPlusGap() {
        let width = KeyboardGeometry.fixedWidth(units: 2, unit: 30, spacing: 6)
        XCTAssertEqual(width, 66, accuracy: 0.001)
    }

    func testTotalHeight() {
        let metrics = KeyboardMetrics.portrait
        let expected: CGFloat = 8 + 4 + 168 + 33
        XCTAssertEqual(metrics.totalHeight(rowCount: 4), expected, accuracy: 0.001)
    }

    func testInsertedTextRespectsCase() {
        let key = Key(.character("a"))
        XCTAssertEqual(key.insertedText(uppercased: true), "A")
        XCTAssertEqual(key.insertedText(uppercased: false), "a")
        XCTAssertNil(Key(.space).insertedText(uppercased: true))
    }
}
