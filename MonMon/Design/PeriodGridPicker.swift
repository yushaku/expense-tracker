import SwiftUI

/// The month and year pickers behind the date filter's Month and Year tabs.
///
/// A day calendar cannot pick a month without the owner picking an arbitrary day
/// inside it, and a whole year even less so. Both are drawn as grids of the
/// thing being chosen instead, over the same span of years the day calendar
/// scrolls through.
enum PeriodGrid {
    /// The years both pickers offer, oldest first. Same window as the day
    /// calendar, so no screen offers a period another one cannot reach.
    static var years: [Int] {
        let calendar = TransactionPeriod.calendar
        let first = calendar.component(.year, from: CalendarTheme.startMonth())
        let last = calendar.component(.year, from: CalendarTheme.endMonth())

        return Array(first...max(first, last))
    }

    static func date(year: Int, month: Int) -> Date {
        TransactionPeriod.calendar.date(from: DateComponents(year: year, month: month)) ?? .now
    }

    static func date(year: Int) -> Date {
        date(year: year, month: 1)
    }

    /// Whether a grid cell names the period the device clock is inside. A
    /// missing month asks about the whole year.
    static func isCurrent(year: Int, month: Int? = nil, now: Date = .now) -> Bool {
        let unit: PeriodRailUnit = month == nil ? .year : .month
        return unit.marksNow(date(year: year, month: month ?? 1), now: now)
    }

    /// The twelve month names in the language on show. Built per call rather
    /// than stored, because a stored list would keep the language the app
    /// happened to launch in.
    static func monthNames(in locale: Locale) -> [String] {
        let style = TransactionPeriod.format(Date.FormatStyle().month(.abbreviated), in: locale)

        return (1...12).map { style.format(date(year: 2000, month: $0)) }
    }
}

/// A year at a time, twelve months to a card. Scrolls straight to the year on
/// show, so picking last March is a scroll away rather than a dozen taps.
struct MonthGridPicker: View {
    @Binding var selection: Date

    @Environment(\.locale) private var locale

    let accessibilityIdentifier: String

    private var calendar: Calendar {
        TransactionPeriod.calendar
    }

    private var selectedYear: Int {
        calendar.component(.year, from: selection)
    }

    private var selectedMonth: Int {
        calendar.component(.month, from: selection)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(PeriodGrid.years, id: \.self) { year in
                        yearBlock(year)
                            .id(year)
                    }
                }
                .padding(4)
            }
            .onAppear {
                proxy.scrollTo(selectedYear, anchor: .center)
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func yearBlock(_ year: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(year))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)) {
                ForEach(1...12, id: \.self) { month in
                    monthCell(year: year, month: month)
                }
            }
        }
    }

    private func monthCell(year: Int, month: Int) -> some View {
        let isSelected = year == selectedYear && month == selectedMonth
        let isCurrent = PeriodGrid.isCurrent(year: year, month: month)

        return Button {
            selection = PeriodGrid.date(year: year, month: month)
        } label: {
            Text(PeriodGrid.monthNames(in: locale)[month - 1])
                .font(.subheadline.weight(isSelected ? .bold : (isCurrent ? .semibold : .medium)))
                .foregroundStyle(
                    isSelected
                        ? MonMonTheme.onAccent
                        : (isCurrent ? MonMonTheme.accent : MonMonTheme.textPrimary)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                                ? MonMonTheme.accent
                                : (isCurrent ? MonMonTheme.accent.opacity(0.14) : MonMonTheme.field)
                        )
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            isCurrent
                                ? (isSelected
                                    ? MonMonTheme.onAccent.opacity(0.8)
                                    : MonMonTheme.accent.opacity(0.65))
                                : Color.clear,
                            lineWidth: 1.5
                        )
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(PeriodGrid.monthNames(in: locale)[month - 1]) \(year)")
        .accessibilityValue(isCurrent ? Text("Current month") : Text(""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The same idea one step wider: every year the app offers, three to a row.
struct YearGridPicker: View {
    @Binding var selection: Date

    let accessibilityIdentifier: String

    private var selectedYear: Int {
        TransactionPeriod.calendar.component(.year, from: selection)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)) {
                    ForEach(PeriodGrid.years, id: \.self) { year in
                        yearCell(year)
                            .id(year)
                    }
                }
                .padding(4)
            }
            .onAppear {
                proxy.scrollTo(selectedYear, anchor: .center)
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func yearCell(_ year: Int) -> some View {
        let isSelected = year == selectedYear
        let isCurrent = PeriodGrid.isCurrent(year: year)

        return Button {
            selection = PeriodGrid.date(year: year)
        } label: {
            Text(String(year))
                .font(.subheadline.weight(isSelected ? .bold : (isCurrent ? .semibold : .medium)))
                .monospacedDigit()
                .foregroundStyle(
                    isSelected
                        ? MonMonTheme.onAccent
                        : (isCurrent ? MonMonTheme.accent : MonMonTheme.textPrimary)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                                ? MonMonTheme.accent
                                : (isCurrent ? MonMonTheme.accent.opacity(0.14) : MonMonTheme.field)
                        )
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            isCurrent
                                ? (isSelected
                                    ? MonMonTheme.onAccent.opacity(0.8)
                                    : MonMonTheme.accent.opacity(0.65))
                                : Color.clear,
                            lineWidth: 1.5
                        )
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityValue(isCurrent ? Text("Current year") : Text(""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#if DEBUG
    private struct PeriodGridPickerPreview: View {
        @State private var month = Date(timeIntervalSince1970: 1_787_000_000)
        @State private var year = Date(timeIntervalSince1970: 1_787_000_000)

        var body: some View {
            HStack(alignment: .top, spacing: 16) {
                MonthGridPicker(selection: $month, accessibilityIdentifier: "preview-months")
                YearGridPicker(selection: $year, accessibilityIdentifier: "preview-years")
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MonMonTheme.canvas)
        }
    }

    #Preview("Period grids") {
        PeriodGridPickerPreview()
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
