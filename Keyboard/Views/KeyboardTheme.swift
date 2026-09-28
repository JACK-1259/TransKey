import UIKit

/// 키보드 색상. 모두 동적 색이라 `overrideUserInterfaceStyle`만 바꾸면 라이트/다크가 전환된다.
enum KeyboardTheme {
    static let characterKey = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white
    }

    static let functionKey = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.27, alpha: 1)
            : UIColor(red: 0.67, green: 0.69, blue: 0.73, alpha: 1)
    }

    static let accentKey = UIColor.systemBlue

    static let keyText = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .black
    }

    static let keyShadow = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0, alpha: 0.6)
            : UIColor(white: 0, alpha: 0.3)
    }

    static let secondaryText = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.7, alpha: 1) : UIColor(white: 0.35, alpha: 1)
    }

    static let keyCornerRadius: CGFloat = 6
}
