import UIKit

/// 문자 키를 누르는 동안 키 위에 확대된 글자를 보여주는 말풍선.
/// 좌표는 모두 팝업을 담는 컨테이너 뷰 기준이다.
final class KeyPopupView: UIView {
    private let shapeLayer = CAShapeLayer()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.addSublayer(shapeLayer)
        shapeLayer.shadowOffset = CGSize(width: 0, height: 1)
        shapeLayer.shadowOpacity = 1
        shapeLayer.shadowRadius = 1.5
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 34, weight: .regular)
        addSubview(label)
        isAccessibilityElement = false
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: KeyPopupView, _) in
            view.updateColors()
        }
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// - Parameters:
    ///   - keyFrame: 눌린 키의 프레임(컨테이너 좌표).
    ///   - containerBounds: 말풍선이 벗어나면 안 되는 영역.
    func show(text: String, keyFrame: CGRect, in containerBounds: CGRect) {
        label.text = text
        frame = containerBounds
        let neck: CGFloat = 6
        let extra = min(12, keyFrame.width * 0.35)
        var bubble = CGRect(
            x: keyFrame.minX - extra,
            y: 0,
            width: keyFrame.width + extra * 2,
            height: min(keyFrame.height * 1.1, max(keyFrame.height * 0.8, keyFrame.minY - neck))
        )
        bubble.origin.y = keyFrame.minY - neck - bubble.height
        // 좌우 가장자리 키(q, p 등)는 말풍선을 안쪽으로 밀어 넣는다.
        if bubble.minX < containerBounds.minX { bubble.origin.x = containerBounds.minX }
        if bubble.maxX > containerBounds.maxX { bubble.origin.x = containerBounds.maxX - bubble.width }
        bubble.origin.y = max(containerBounds.minY, bubble.origin.y)

        shapeLayer.path = Self.path(bubble: bubble, key: keyFrame).cgPath
        label.frame = bubble
        isHidden = false
    }

    func hide() {
        isHidden = true
    }

    private func updateColors() {
        shapeLayer.fillColor = KeyboardTheme.characterKey.resolvedColor(with: traitCollection).cgColor
        shapeLayer.shadowColor = KeyboardTheme.keyShadow.resolvedColor(with: traitCollection).cgColor
        label.textColor = KeyboardTheme.keyText
    }

    private static func path(bubble: CGRect, key: CGRect) -> UIBezierPath {
        let r = KeyboardTheme.keyCornerRadius
        let bubbleRadius: CGFloat = 10
        let path = UIBezierPath()
        path.move(to: CGPoint(x: key.minX, y: key.maxY - r))
        path.addLine(to: CGPoint(x: key.minX, y: key.minY))
        path.addQuadCurve(to: CGPoint(x: bubble.minX, y: bubble.maxY),
                          controlPoint: CGPoint(x: key.minX, y: bubble.maxY))
        path.addLine(to: CGPoint(x: bubble.minX, y: bubble.minY + bubbleRadius))
        path.addArc(withCenter: CGPoint(x: bubble.minX + bubbleRadius, y: bubble.minY + bubbleRadius),
                    radius: bubbleRadius, startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
        path.addLine(to: CGPoint(x: bubble.maxX - bubbleRadius, y: bubble.minY))
        path.addArc(withCenter: CGPoint(x: bubble.maxX - bubbleRadius, y: bubble.minY + bubbleRadius),
                    radius: bubbleRadius, startAngle: .pi * 1.5, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: bubble.maxX, y: bubble.maxY))
        path.addQuadCurve(to: CGPoint(x: key.maxX, y: key.minY),
                          controlPoint: CGPoint(x: key.maxX, y: bubble.maxY))
        path.addLine(to: CGPoint(x: key.maxX, y: key.maxY - r))
        path.addArc(withCenter: CGPoint(x: key.maxX - r, y: key.maxY - r),
                    radius: r, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: key.minX + r, y: key.maxY))
        path.addArc(withCenter: CGPoint(x: key.minX + r, y: key.maxY - r),
                    radius: r, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.close()
        return path
    }
}
