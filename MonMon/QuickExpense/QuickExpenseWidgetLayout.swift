import Foundation

/// How many preset buttons each widget size holds, and how they sit in it.
///
/// Two different questions used to be answered by one set of numbers. The owner
/// chose how many presets to keep — and could only say three, six or nine,
/// because those were the counts the widget sizes happened to fit. Capacity is
/// a property of the size; how many presets exist is the owner's. This type
/// answers only the first, so the second is free to be any number.
///
/// Deliberately free of WidgetKit: the app target reads it to describe the
/// sizes in Settings, and the layout maths is worth testing without a widget
/// host. The widget maps its `WidgetFamily` onto `Size` at the boundary.
enum QuickExpenseWidgetLayout {
    enum Size: String, CaseIterable, Sendable {
        case small
        case medium
        case large

        var displayNameKey: String {
            switch self {
            case .small:
                "small"
            case .medium:
                "medium"
            case .large:
                "large"
            }
        }
    }

    /// The most buttons this size can show at a legible tap target.
    ///
    /// Medium holds eight rather than six: it is two rows of a wide, short
    /// space, and four across fits without shrinking a button below a thumb.
    static func capacity(_ size: Size) -> Int {
        switch size {
        case .small:
            3
        case .medium:
            8
        case .large:
            9
        }
    }

    /// How many of the owner's presets this size actually shows.
    static func visibleCount(configured: Int, size: Size) -> Int {
        max(0, min(configured, capacity(size)))
    }

    /// The grid width for a given number of buttons.
    ///
    /// Chosen so a size never grows a row it has no height for: small stacks
    /// one per row, medium fills at most two rows, large at most three. A count
    /// that fits on one row uses one row, so three presets on a medium widget
    /// are three across rather than two above one.
    static func columns(visible: Int, size: Size) -> Int {
        let count = max(1, min(visible, capacity(size)))

        switch size {
        case .small:
            return 1
        case .medium:
            return count <= 4 ? count : rowWidth(count, rows: 2)
        case .large:
            return count <= 3 ? count : 3
        }
    }

    /// The narrowest grid that fits `count` into `rows`.
    private static func rowWidth(_ count: Int, rows: Int) -> Int {
        (count + rows - 1) / rows
    }
}
