import SwiftUI

/// Catppuccin (https://catppuccin.com/palette/): Latte in light, Frappé in dark.
///
/// Every semantic colour below resolves per appearance, so the whole app follows
/// the owner's theme choice without a single call site asking which one is on.
enum MonMonTheme {
    /// Raw Latte values. Light flavour.
    enum Latte {
        static let pink: UInt32 = 0xEA76CB
        static let mauve: UInt32 = 0x8839EF
        static let red: UInt32 = 0xD20F39
        static let peach: UInt32 = 0xFE640B
        static let yellow: UInt32 = 0xDF8E1D
        static let green: UInt32 = 0x40A02B
        static let teal: UInt32 = 0x179299
        static let sky: UInt32 = 0x04A5E5
        static let blue: UInt32 = 0x1E66F5
        static let lavender: UInt32 = 0x7287FD
        static let text: UInt32 = 0x4C4F69
        static let subtext0: UInt32 = 0x6C6F85
        static let overlay1: UInt32 = 0x8C8FA1
        static let surface2: UInt32 = 0xACB0BE
        static let surface0: UInt32 = 0xCCD0DA
        static let base: UInt32 = 0xEFF1F5
        static let mantle: UInt32 = 0xE6E9EF
        static let crust: UInt32 = 0xDCE0E8
    }

    /// Raw Frappé values. Dark flavour.
    enum Frappe {
        static let pink: UInt32 = 0xF4B8E4
        static let mauve: UInt32 = 0xCA9EE6
        static let red: UInt32 = 0xE78284
        static let peach: UInt32 = 0xEF9F76
        static let yellow: UInt32 = 0xE5C890
        static let green: UInt32 = 0xA6D189
        static let teal: UInt32 = 0x81C8BE
        static let sky: UInt32 = 0x99D1DB
        static let blue: UInt32 = 0x8CAAEE
        static let lavender: UInt32 = 0xBABBF1
        static let text: UInt32 = 0xC6D0F5
        static let subtext0: UInt32 = 0xA5ADCE
        static let overlay1: UInt32 = 0x838BA7
        static let surface2: UInt32 = 0x626880
        static let surface1: UInt32 = 0x51576D
        static let surface0: UInt32 = 0x414559
        static let base: UInt32 = 0x303446
        static let mantle: UInt32 = 0x292C3C
        static let crust: UInt32 = 0x232634
    }

    /// The named hues, for anything that picks a colour by name rather than by
    /// role — a category's icon, say.
    enum Hue {
        static let pink = Color(light: Latte.pink, dark: Frappe.pink)
        static let mauve = Color(light: Latte.mauve, dark: Frappe.mauve)
        static let red = Color(light: Latte.red, dark: Frappe.red)
        static let peach = Color(light: Latte.peach, dark: Frappe.peach)
        static let yellow = Color(light: Latte.yellow, dark: Frappe.yellow)
        static let green = Color(light: Latte.green, dark: Frappe.green)
        static let teal = Color(light: Latte.teal, dark: Frappe.teal)
        static let sky = Color(light: Latte.sky, dark: Frappe.sky)
        static let blue = Color(light: Latte.blue, dark: Frappe.blue)
        static let lavender = Color(light: Latte.lavender, dark: Frappe.lavender)
    }

    static let accent = Hue.green
    static let onAccent = Color(light: Latte.base, dark: Frappe.crust)
    static let bank = Hue.blue
    static let credit = Hue.peach
    static let savings = Hue.yellow
    static let funds = Hue.mauve
    /// Coins. Held alongside funds and gold in the same ring, so it takes the
    /// last hue those had not claimed rather than a shade of either.
    static let crypto = Hue.lavender
    /// Money lent out. It has to read as an asset without reading as
    /// spendable cash, a term deposit, a market gain, or a bank account, so
    /// it takes the one hue none of those had claimed. Money borrowed reuses
    /// `credit`, which is already this app's colour for money owed.
    static let lent = Hue.sky
    static let gain = Hue.teal
    static let danger = Hue.red

    // Light stacks the other way round from dark: a card sits lighter than the
    // page it is on, and an inset field sits darker than the card.
    static let canvas = Color(light: Latte.mantle, dark: Frappe.base)
    static let surface = Color(light: Latte.base, dark: Frappe.surface0)
    static let field = Color(light: Latte.crust, dark: Frappe.surface1)
    static let hero = Color(light: Latte.base, dark: Frappe.mantle)
    static let border = Color(light: Latte.surface2, dark: Frappe.surface2).opacity(0.55)
    static let heroBorder = Color(light: Latte.surface0, dark: Frappe.surface2).opacity(0.45)

    static let textPrimary = Color(light: Latte.text, dark: Frappe.text)
    static let textSecondary = Color(light: Latte.subtext0, dark: Frappe.subtext0)
    static let textMuted = Color(light: Latte.overlay1, dark: Frappe.overlay1)

    /// `nil` follows the system. Read straight from the stored setting, so the
    /// twenty-odd views that pin their own colour scheme — a sheet does not
    /// inherit one from the screen that presented it — need no change.
    static var colorScheme: ColorScheme? {
        AppTheme.stored.colorScheme
    }

    static let cardRadius: CGFloat = 20
    static let contentSpacing: CGFloat = 20
    static let maxContentWidth: CGFloat = 720
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Resolves per appearance, so a view never has to ask which theme is on.
    init(light: UInt32, dark: UInt32) {
        #if os(macOS)
            self.init(
                nsColor: NSColor(name: nil) { appearance in
                    let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    return NSColor(Color(hex: isDark ? dark : light))
                }
            )
        #else
            self.init(
                uiColor: UIColor { traits in
                    UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
                }
            )
        #endif
    }
}
