import SwiftUI

extension Notification.Name {
    static let tiqDoAppearanceChanged = Notification.Name("tiqDoAppearanceChanged")
}

enum Theme {
    static let customDark = Color(nsColor: .init(red: 0.11, green: 0.12, blue: 0.16, alpha: 1))
    static let nsCustomDark = NSColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1)

    static func nsBg(for mode: AppearanceMode) -> NSColor {
        switch mode {
        case .dark: nsCustomDark
        case .light: .windowBackgroundColor
        case .system: .windowBackgroundColor
        }
    }
}
