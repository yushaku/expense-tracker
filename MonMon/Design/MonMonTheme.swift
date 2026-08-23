import SwiftUI

/// Catppuccin Frappé palette (https://catppuccin.com/palette/).
/// Frappé is a dark-only flavour, so the app pins its colour scheme to dark.
enum MonMonTheme {
    enum Frappe {
        static let rosewater = Color(hex: 0xF2D5CF)
        static let flamingo = Color(hex: 0xEEBEBE)
        static let pink = Color(hex: 0xF4B8E4)
        static let mauve = Color(hex: 0xCA9EE6)
        static let red = Color(hex: 0xE78284)
        static let maroon = Color(hex: 0xEA999C)
        static let peach = Color(hex: 0xEF9F76)
        static let yellow = Color(hex: 0xE5C890)
        static let green = Color(hex: 0xA6D189)
        static let teal = Color(hex: 0x81C8BE)
        static let sky = Color(hex: 0x99D1DB)
        static let sapphire = Color(hex: 0x85C1DC)
        static let blue = Color(hex: 0x8CAAEE)
        static let lavender = Color(hex: 0xBABBF1)
        static let text = Color(hex: 0xC6D0F5)
        static let subtext1 = Color(hex: 0xB5BFE2)
        static let subtext0 = Color(hex: 0xA5ADCE)
        static let overlay2 = Color(hex: 0x949CBB)
        static let overlay1 = Color(hex: 0x838BA7)
        static let overlay0 = Color(hex: 0x737994)
        static let surface2 = Color(hex: 0x626880)
        static let surface1 = Color(hex: 0x51576D)
        static let surface0 = Color(hex: 0x414559)
        static let base = Color(hex: 0x303446)
        static let mantle = Color(hex: 0x292C3C)
        static let crust = Color(hex: 0x232634)
    }

    static let accent = Frappe.green
    static let onAccent = Frappe.crust
    static let bank = Frappe.blue
    static let savings = Frappe.yellow
    static let danger = Frappe.red

    static let canvas = Frappe.base
    static let surface = Frappe.surface0
    static let field = Frappe.surface1
    static let hero = Frappe.mantle
    static let border = Frappe.surface2.opacity(0.55)
    static let heroBorder = Frappe.surface2.opacity(0.45)

    static let textPrimary = Frappe.text
    static let textSecondary = Frappe.subtext0
    static let textMuted = Frappe.overlay1

    static let colorScheme: ColorScheme = .dark

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
}
