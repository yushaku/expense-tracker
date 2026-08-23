import SwiftUI

/// The symbols and colours a category may use. A category stores names from
/// these lists rather than a raw symbol or colour, so an unknown value falls
/// back to something renderable instead of breaking the row.
enum CategoryPalette {
    static let symbolNames = [
        "fork.knife",
        "car.fill",
        "house.fill",
        "cart.fill",
        "cross.case.fill",
        "gamecontroller.fill",
        "bag.fill",
        "airplane",
        "book.fill",
        "gift.fill",
        "bolt.fill",
        "phone.fill",
        "pawprint.fill",
        "dumbbell.fill",
        "briefcase.fill",
        "banknote.fill",
        "building.columns.fill",
        "chart.line.uptrend.xyaxis",
        "tag.fill",
    ]

    static let colorNames = [
        "green",
        "blue",
        "peach",
        "yellow",
        "mauve",
        "teal",
        "sky",
        "pink",
        "lavender",
        "red",
    ]

    static let defaultSymbolName = "tag.fill"
    static let defaultColorName = "green"

    static func symbolName(_ name: String) -> String {
        symbolNames.contains(name) ? name : defaultSymbolName
    }

    static func colorName(_ name: String) -> String {
        colorNames.contains(name) ? name : defaultColorName
    }

    static func color(named name: String) -> Color {
        switch colorName(name) {
        case "blue":
            MonMonTheme.Frappe.blue
        case "peach":
            MonMonTheme.Frappe.peach
        case "yellow":
            MonMonTheme.Frappe.yellow
        case "mauve":
            MonMonTheme.Frappe.mauve
        case "teal":
            MonMonTheme.Frappe.teal
        case "sky":
            MonMonTheme.Frappe.sky
        case "pink":
            MonMonTheme.Frappe.pink
        case "lavender":
            MonMonTheme.Frappe.lavender
        case "red":
            MonMonTheme.Frappe.red
        default:
            MonMonTheme.Frappe.green
        }
    }
}
