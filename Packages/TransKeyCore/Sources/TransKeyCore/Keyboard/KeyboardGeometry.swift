import CoreGraphics

/// 자판 치수. 기기 크기와 방향에 따라 선택한다.
public struct KeyboardMetrics: Hashable, Sendable {
    public var keyHeight: CGFloat
    public var rowSpacing: CGFloat
    public var keySpacing: CGFloat
    public var sideInset: CGFloat
    public var topInset: CGFloat
    public var bottomInset: CGFloat

    public init(keyHeight: CGFloat, rowSpacing: CGFloat, keySpacing: CGFloat,
                sideInset: CGFloat, topInset: CGFloat, bottomInset: CGFloat) {
        self.keyHeight = keyHeight
        self.rowSpacing = rowSpacing
        self.keySpacing = keySpacing
        self.sideInset = sideInset
        self.topInset = topInset
        self.bottomInset = bottomInset
    }

    /// iPhone 세로 모드(시스템 키보드와 비슷한 비율).
    public static let portrait = KeyboardMetrics(
        keyHeight: 42, rowSpacing: 11, keySpacing: 6, sideInset: 3, topInset: 8, bottomInset: 4
    )

    /// iPhone 가로 모드. 세로 공간이 좁으므로 키 높이를 줄인다.
    public static let landscape = KeyboardMetrics(
        keyHeight: 32, rowSpacing: 6, keySpacing: 6, sideInset: 3, topInset: 5, bottomInset: 3
    )

    public func totalHeight(rowCount: Int) -> CGFloat {
        guard rowCount > 0 else { return topInset + bottomInset }
        return topInset + bottomInset
            + CGFloat(rowCount) * keyHeight
            + CGFloat(rowCount - 1) * rowSpacing
    }
}

/// 자판 레이아웃을 실제 프레임으로 변환한다.
public enum KeyboardGeometry {
    /// 10열 기준 표준 키 한 칸의 폭.
    public static func unitWidth(totalWidth: CGFloat, metrics: KeyboardMetrics) -> CGFloat {
        let content = totalWidth - metrics.sideInset * 2 - metrics.keySpacing * 9
        return max(0, content / 10)
    }

    /// 각 키의 프레임을 행 단위로 반환한다. 좌표 원점은 자판 영역의 좌상단이다.
    public static func frames(for layout: KeyboardLayout, width: CGFloat,
                              metrics: KeyboardMetrics) -> [[CGRect]] {
        let unit = unitWidth(totalWidth: width, metrics: metrics)
        let contentWidth = max(0, width - metrics.sideInset * 2)

        return layout.rows.enumerated().map { rowIndex, row in
            let y = metrics.topInset + CGFloat(rowIndex) * (metrics.keyHeight + metrics.rowSpacing)
            let widths = resolvedWidths(for: row, unit: unit, contentWidth: contentWidth,
                                        spacing: metrics.keySpacing)
            let xs = originXs(for: row, widths: widths, contentWidth: contentWidth,
                              spacing: metrics.keySpacing, sideInset: metrics.sideInset)
            return zip(xs, widths).map { x, w in
                CGRect(x: x, y: y, width: w, height: metrics.keyHeight)
            }
        }
    }

    static func fixedWidth(units: Double, unit: CGFloat, spacing: CGFloat) -> CGFloat {
        // 2칸 키는 표준 키 2개 + 사이 간격 1개와 같은 폭이 되도록 한다.
        let u = CGFloat(units)
        return u * unit + max(0, u - 1) * spacing
    }

    private static func resolvedWidths(for row: KeyboardRow, unit: CGFloat,
                                       contentWidth: CGFloat, spacing: CGFloat) -> [CGFloat] {
        var fixedTotal: CGFloat = 0
        var flexibleCount = 0
        for key in row.keys {
            switch key.width {
            case .units(let units): fixedTotal += fixedWidth(units: units, unit: unit, spacing: spacing)
            case .flexible: flexibleCount += 1
            }
        }
        let gaps = CGFloat(max(0, row.keys.count - 1)) * spacing
        let flexibleWidth = flexibleCount > 0
            ? max(0, (contentWidth - fixedTotal - gaps) / CGFloat(flexibleCount))
            : 0
        return row.keys.map { key in
            switch key.width {
            case .units(let units): fixedWidth(units: units, unit: unit, spacing: spacing)
            case .flexible: flexibleWidth
            }
        }
    }

    private static func originXs(for row: KeyboardRow, widths: [CGFloat], contentWidth: CGFloat,
                                 spacing: CGFloat, sideInset: CGFloat) -> [CGFloat] {
        guard !widths.isEmpty else { return [] }
        let hasFlexible = row.keys.contains { $0.width == .flexible }

        if row.alignment == .spread, !hasFlexible, widths.count >= 3,
           let firstWidth = widths.first, let lastWidth = widths.last {
            var result = [sideInset]
            let middle = Array(widths.dropFirst().dropLast())
            let middleTotal = middle.reduce(0, +) + CGFloat(max(0, middle.count - 1)) * spacing
            let freeStart = sideInset + firstWidth
            let freeWidth = contentWidth - firstWidth - lastWidth
            var x = freeStart + (freeWidth - middleTotal) / 2
            for w in middle {
                result.append(x)
                x += w + spacing
            }
            result.append(sideInset + contentWidth - lastWidth)
            return result
        }

        let total = widths.reduce(0, +) + CGFloat(widths.count - 1) * spacing
        var x = sideInset + (hasFlexible ? 0 : (contentWidth - total) / 2)
        return widths.map { w in
            defer { x += w + spacing }
            return x
        }
    }
}
