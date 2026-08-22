import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

enum MonMonTheme {
    static let accent = Color(red: 0.02, green: 0.42, blue: 0.30)
    static let hero = Color(red: 0.035, green: 0.12, blue: 0.16)
    static let bank = Color(red: 0.10, green: 0.38, blue: 0.67)
    static let border = Color.secondary.opacity(0.16)

    static let cardRadius: CGFloat = 20
    static let contentSpacing: CGFloat = 20
    static let maxContentWidth: CGFloat = 720

    #if os(iOS)
        static let canvas = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let field = Color(uiColor: .tertiarySystemGroupedBackground)
    #elseif os(macOS)
        static let canvas = Color(nsColor: .windowBackgroundColor)
        static let surface = Color(nsColor: .controlBackgroundColor)
        static let field = Color(nsColor: .textBackgroundColor)
    #endif
}
