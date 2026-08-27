import MijickCalendarView
import SwiftUI

/// The insides of the date filter: the scope tabs, and under them the picker
/// that scope calls for — a day calendar, a grid of months, a grid of years, or
/// a calendar the owner draws a span across.
///
/// It is tall enough to crowd a card, so screens reach for it through
/// `DateRangeFilterButton`, which keeps it in a sheet behind a small button and
/// leaves only the range's name on the screen itself.
///
/// It owns no range of its own. The screen keeps it, so the same control serves
/// the Spending screen and the Accounts screen without either learning about the
/// other.
struct DateRangeFilter: View {
    @Binding var range: TransactionRange

    @Environment(\.locale) private var locale

    /// Prefixes the accessibility identifiers, so two filters on one screen stay
    /// tellable apart. Empty leaves the plain names the Spending screen has
    /// always used.
    var identifierPrefix: String = ""

    /// The calendar's own idea of the span being drawn. It cannot be derived
    /// from `range`: the library builds a span across two taps, and a binding
    /// that reported a finished span after the first tap would make every second
    /// tap start over instead of closing the span.
    @State private var pickedRange: MDateRange?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            scopePicker

            periodHeader

            picker
        }
        .onAppear(perform: seedPickedRange)
        .onChange(of: range.scope) { _, _ in
            seedPickedRange()
        }
        .onChange(of: pickedRange?.getRange()) { _, picked in
            guard let picked else {
                return
            }

            range = .custom(from: picked.lowerBound, to: picked.upperBound)
        }
    }

    /// The anchor a scope change re-cuts around: today when it is on show, and
    /// otherwise the start of what is, so the owner keeps their place.
    private var anchor: Date {
        range.contains(.now) ? .now : range.start
    }

    /// Switching scope keeps the owner near what they were looking at, so a
    /// month spent browsing last March narrows to a day in last March rather
    /// than jumping to today.
    private var scopeSelection: Binding<TransactionRangeScope> {
        Binding(
            get: { range.scope },
            set: { range = range.scoped(to: $0, anchoredOn: anchor) }
        )
    }

    private var scopePicker: some View {
        SegmentedTabs(
            label: "Period",
            selection: scopeSelection,
            options: TransactionRangeScope.allCases,
            title: \.displayName
        )
        .accessibilityIdentifier(identifier("period-scope"))
    }

    /// The name of what is picked. A hand-picked span names both of its ends
    /// instead, since the two dates are what the owner is placing.
    @ViewBuilder
    private var periodHeader: some View {
        if range.scope == .custom {
            HStack(spacing: 12) {
                endLabel("From", date: range.start)
                endLabel("To", date: range.lastDay)
            }
        } else {
            Text(range.title(in: locale).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(MonMonTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func endLabel(_ title: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(TransactionPeriod.format(Self.dayTemplate, in: locale).format(date))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(MonMonTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var picker: some View {
        switch range.scope {
        case .day:
            dayCalendar

        case .month:
            MonthGridPicker(
                selection: monthSelection,
                accessibilityIdentifier: identifier("month-grid")
            )
            .padding(12)
            .background(pickerBackground)

        case .year:
            YearGridPicker(
                selection: yearSelection,
                accessibilityIdentifier: identifier("year-grid")
            )
            .padding(12)
            .background(pickerBackground)

        case .custom:
            VStack(alignment: .leading, spacing: 10) {
                rangeCalendar

                Text("Tap the first day, then the last. Tapping again starts a new span.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var dayCalendar: some View {
        MCalendarView(selectedDate: daySelection, selectedRange: nil) {
            calendar($0, scrollingTo: range.start, dayView: ThemedDayView.day)
        }
        .frame(minHeight: 320)
        .padding(12)
        .background(pickerBackground)
        .accessibilityIdentifier(identifier("day-calendar"))
    }

    /// A month calendar the owner taps twice: once for the first day, once for
    /// the last. A third tap starts a new span, which is how the library reads a
    /// tap on an already-finished range.
    private var rangeCalendar: some View {
        MCalendarView(selectedDate: nil, selectedRange: $pickedRange) {
            calendar($0, scrollingTo: range.start, dayView: ThemedDayView.range)
        }
        .frame(minHeight: 320)
        .padding(12)
        .background(pickerBackground)
        .accessibilityIdentifier(identifier("range-calendar"))
    }

    private func calendar(
        _ config: CalendarConfig,
        scrollingTo date: Date,
        dayView: @escaping (Date, Bool, Binding<Date?>?, Binding<MDateRange?>?) -> any DayView
    ) -> CalendarConfig {
        config
            .startMonth(CalendarTheme.startMonth())
            .endMonth(CalendarTheme.endMonth())
            .dayView(dayView)
            .monthLabel(ThemedMonthLabel.init)
            .weekdaysView(ThemedWeekdaysView.init)
            .monthLabelToDaysDistance(14)
            .daysVerticalSpacing(4)
            .monthsViewBackground(MonMonTheme.surface)
            .scrollTo(date: date)
    }

    private var pickerBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(MonMonTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
    }

    /// The day calendar hands back an optional date and expects to keep offering
    /// one; a range always has a day, so a cleared selection keeps the current
    /// one rather than leaving the filter with nothing picked.
    private var daySelection: Binding<Date?> {
        Binding(
            get: { range.start },
            set: { picked in
                guard let picked else {
                    return
                }

                range = .day(containing: picked)
            }
        )
    }

    private var monthSelection: Binding<Date> {
        Binding(
            get: { range.start },
            set: { range = .month(containing: $0) }
        )
    }

    private var yearSelection: Binding<Date> {
        Binding(
            get: { range.start },
            set: { range = .year(containing: $0) }
        )
    }

    /// Hands the calendar the span already on show, so opening the filter starts
    /// from what the owner is looking at rather than from nothing.
    private func seedPickedRange() {
        guard range.scope == .custom else {
            pickedRange = nil
            return
        }

        pickedRange = MDateRange(startDate: range.start, endDate: range.lastDay)
    }

    private func identifier(_ name: String) -> String {
        identifierPrefix.isEmpty ? name : "\(identifierPrefix)-\(name)"
    }

    private static let dayTemplate = Date.FormatStyle().day().month(.abbreviated).year()
}

/// The small button a section title carries to change what slice of time it is
/// showing. It opens `DateRangeFilter` in a sheet.
///
/// The tabs and pickers used to sit in the screen itself, which cost three
/// stacked rows above every list and made the card they were in read as a form
/// rather than a summary. Behind a button they cost one glyph, and the range
/// they picked stays legible because the screen writes its name beside them.
struct DateRangeFilterButton: View {
    @Binding var range: TransactionRange

    @Environment(\.locale) private var locale

    /// Prefixes the accessibility identifiers, so two filters on one screen stay
    /// tellable apart. Empty leaves the plain names the Spending screen has
    /// always used.
    var identifierPrefix: String = ""

    /// The glyph the button wears. A screen that already steps its own months
    /// asks for a calendar, which names what the sheet holds; a screen that only
    /// narrows a list keeps the filter lines.
    var systemImage: String = "line.3.horizontal.decrease"

    @State private var isFiltering = false

    var body: some View {
        Button {
            isFiltering = true
        } label: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.bold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 30, height: 30)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by date")
        .accessibilityValue(range.title(in: locale))
        .accessibilityIdentifier(identifier("period-filter"))
        .appSheet(isPresented: $isFiltering) {
            sheet
        }
    }

    private var sheet: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                // No scroll view around this: every picker it shows scrolls on
                // its own, by month or by year.
                VStack(alignment: .leading, spacing: 0) {
                    DateRangeFilter(range: $range, identifierPrefix: identifierPrefix)
                        .frame(maxWidth: MonMonTheme.maxContentWidth)

                    Spacer(minLength: 0)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Period")
            .accessibilityIdentifier(identifier("period-filter-sheet"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isFiltering = false
                    }
                    .accessibilityIdentifier(identifier("period-filter-done"))
                }
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
        #if os(macOS)
            .frame(minWidth: 420, minHeight: 520)
        #else
            .presentationDetents([.large])
        #endif
    }

    private func identifier(_ name: String) -> String {
        identifierPrefix.isEmpty ? name : "\(identifierPrefix)-\(name)"
    }
}

#if DEBUG
    private struct DateRangeFilterPreview: View {
        @Environment(\.locale) private var locale

        @State private var range = TransactionRange.month(containing: .now)

        var body: some View {
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    Text(range.title(in: locale).uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(MonMonTheme.textSecondary)

                    Spacer()

                    DateRangeFilterButton(range: $range)
                }

                DateRangeFilter(range: $range)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MonMonTheme.canvas)
        }
    }

    #Preview("Date range filter") {
        DateRangeFilterPreview()
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
