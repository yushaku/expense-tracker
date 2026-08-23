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
            MonMonTheme.Hue.blue
        case "peach":
            MonMonTheme.Hue.peach
        case "yellow":
            MonMonTheme.Hue.yellow
        case "mauve":
            MonMonTheme.Hue.mauve
        case "teal":
            MonMonTheme.Hue.teal
        case "sky":
            MonMonTheme.Hue.sky
        case "pink":
            MonMonTheme.Hue.pink
        case "lavender":
            MonMonTheme.Hue.lavender
        case "red":
            MonMonTheme.Hue.red
        default:
            MonMonTheme.Hue.green
        }
    }
}
