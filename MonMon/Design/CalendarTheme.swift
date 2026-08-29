import MijickCalendarView
import SwiftUI

/// The calendar drawn in MonMon's own colours. MijickCalendarView ships its own
/// palette, so every part that carries a colour is replaced here rather than
/// left to clash with the card it sits in.
enum CalendarTheme {
    /// How far back the calendar may be scrolled. Money is recorded after it
    /// moves, so the past is the common case; the library defaults to starting
    /// at the current month, which puts every earlier day out of reach.
    static let yearsBack = 5
    static let yearsAhead = 2

    static func startMonth(from date: Date = .now) -> Date {
        TransactionPeriod.calendar.date(byAdding: .year, value: -yearsBack, to: date) ?? date
    }

    static func endMonth(from date: Date = .now) -> Date {
        TransactionPeriod.calendar.date(byAdding: .year, value: yearsAhead, to: date) ?? date
    }
}

struct ThemedDayView: DayView {
    let date: Date
    let isCurrentMonth: Bool
    let selectedDate: Binding<Date?>?
    let selectedRange: Binding<MDateRange?>?
    /// Which of the two bindings a tap writes to. The library hands every day
    /// view both of them, non-nil, whatever the calendar was asked for, so the
    /// day cannot work this out for itself: a calendar built for one date would
    /// keep opening a span nobody reads, and never write the date.
    let selectsRange: Bool

    /// A calendar that picks one date.
    static func day(
        _ date: Date,
        _ isCurrentMonth: Bool,
        _ selectedDate: Binding<Date?>?,
        _ selectedRange: Binding<MDateRange?>?
    ) -> any DayView {
        ThemedDayView(
            date: date,
            isCurrentMonth: isCurrentMonth,
            selectedDate: selectedDate,
            selectedRange: selectedRange,
            selectsRange: false
        )
    }

    /// A calendar that picks a span of dates.
    static func range(
        _ date: Date,
        _ isCurrentMonth: Bool,
        _ selectedDate: Binding<Date?>?,
        _ selectedRange: Binding<MDateRange?>?
    ) -> any DayView {
        ThemedDayView(
            date: date,
            isCurrentMonth: isCurrentMonth,
            selectedDate: selectedDate,
            selectedRange: selectedRange,
            selectsRange: true
        )
    }

    func createDayLabel() -> AnyView {
        AnyView(
            Text(getStringFromDay(format: "d"))
                .font(.system(size: 14, weight: isToday() ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(labelColor)
        )
    }

    func createSelectionView() -> AnyView {
        AnyView(
            Circle()
                .fill(MonMonTheme.accent)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.52).combined(with: .opacity),
                        removal: .opacity
                    )
                )
                .opacity(isSelected() ? 1 : 0)
        )
    }

    /// The days between the two ends of a picked span. Drawn as a plain band so
    /// the ends keep their circles and the span still reads as one block.
    func createRangeSelectionView() -> AnyView {
        AnyView(
            Rectangle()
                .fill(MonMonTheme.accent.opacity(0.16))
                .opacity(isWithinRange() ? 1 : 0)
        )
    }

    func createContent() -> AnyView {
        AnyView(
            ZStack {
                createRangeSelectionView()

                createSelectionView()

                // Today always keeps a ring, including while selected, so the
                // current day and the owner's selection remain separate facts.
                if isToday() {
                    Circle()
                        .stroke(
                            isSelected()
                                ? MonMonTheme.onAccent.opacity(0.8)
                                : MonMonTheme.accent.opacity(0.55),
                            lineWidth: 1.5
                        )
                }

                createDayLabel()
            }
            // An unselected day draws nothing but its number: the circles behind
            // it sit at zero opacity, and SwiftUI does not hit-test those. Taps
            // then only landed on the digit itself, which made every day but
            // today feel unselectable. The whole square takes the tap instead.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .accessibilityValue(isToday() ? Text("Today") : Text(""))
        )
    }

    /// The library's own tap handler only ever writes a single date, so a
    /// calendar picking a span would look selectable and do nothing. This adds
    /// the tapped day to the span instead: first tap opens it, second closes it,
    /// third starts a new one.
    func onSelection() {
        guard selectsRange, let selectedRange else {
            selectedDate?.wrappedValue = date
            return
        }

        var updated = selectedRange.wrappedValue ?? MDateRange()
        updated.addToRange(date)
        selectedRange.wrappedValue = updated
    }

    private var labelColor: Color {
        if isSelected() {
            return MonMonTheme.onAccent
        }

        return isToday() ? MonMonTheme.accent : MonMonTheme.textPrimary
    }
}

struct ThemedMonthLabel: MonthLabel {
    let month: Date

    func createContent() -> AnyView {
        AnyView(
            Text(getString(format: "MMMM y"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        )
    }
}

struct ThemedWeekdayLabel: WeekdayLabel {
    let weekday: MWeekday

    func createContent() -> AnyView {
        AnyView(
            Text(getString(with: .veryShort))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MonMonTheme.textSecondary)
        )
    }
}

struct ThemedWeekdaysView: WeekdaysView {
    func createWeekdayLabel(_ weekday: MWeekday) -> AnyWeekdayLabel {
        ThemedWeekdayLabel(weekday: weekday).erased()
    }
}
