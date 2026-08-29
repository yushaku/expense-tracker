import SwiftUI

/// The symbols and colours a category may use. A category stores names from
/// these lists rather than a raw symbol or colour, so an unknown value falls
/// back to something renderable instead of breaking the row.
enum CategoryPalette {
    static let symbolNames = [
        // Food and drink
        "fork.knife",
        "cup.and.saucer.fill",
        "takeoutbag.and.cup.and.straw.fill",
        "birthday.cake.fill",
        "wineglass.fill",
        // Transport
        "car.fill",
        "bus.fill",
        "tram.fill",
        "bicycle",
        "figure.walk",
        "airplane",
        "fuelpump.fill",
        // Home and utilities
        "house.fill",
        "bed.double.fill",
        "lightbulb.fill",
        "bolt.fill",
        "drop.fill",
        "flame.fill",
        "wrench.and.screwdriver.fill",
        "wifi",
        // Shopping
        "cart.fill",
        "bag.fill",
        "basket.fill",
        "shippingbox.fill",
        "gift.fill",
        "tshirt.fill",
        // Health
        "cross.case.fill",
        "stethoscope",
        "pills.fill",
        "bandage.fill",
        "heart.fill",
        // Entertainment
        "gamecontroller.fill",
        "film.fill",
        "tv.fill",
        "music.note",
        "headphones",
        "camera.fill",
        "book.fill",
        "newspaper.fill",
        "paintpalette.fill",
        // Sport, education, and work
        "dumbbell.fill",
        "figure.run",
        "sportscourt.fill",
        "graduationcap.fill",
        "laptopcomputer",
        "desktopcomputer",
        "printer.fill",
        // Communication and time
        "phone.fill",
        "envelope.fill",
        "message.fill",
        "calendar",
        "clock.fill",
        "bell.fill",
        // Pets and nature
        "pawprint.fill",
        "leaf.fill",
        "tree.fill",
        "sun.max.fill",
        "umbrella.fill",
        // Money
        "briefcase.fill",
        "banknote.fill",
        "building.columns.fill",
        "creditcard.fill",
        "wallet.bifold.fill",
        "chart.line.uptrend.xyaxis",
        "chart.pie.fill",
        "percent",
        "arrow.left.arrow.right",
        // People and general-purpose categories
        "person.2.fill",
        "tag.fill",
        "star.fill",
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
