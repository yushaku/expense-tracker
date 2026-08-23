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

    func createContent() -> AnyView {
        AnyView(
            ZStack {
                createSelectionView()

                // Today keeps a ring when it is not the selection, so the day
                // is findable without relying on colour alone.
                if isToday(), !isSelected() {
                    Circle()
                        .stroke(MonMonTheme.accent.opacity(0.55), lineWidth: 1.5)
                }

                createDayLabel()
            }
        )
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
