import SwiftUI

/// The unit a rail walks in: one entry per day, per month, or per year, or the
/// single entry a hand-picked span gets.
///
/// It is the bridge between what the header is filtering by and what the rail
/// offers, so the two can never disagree about how wide a step is.
enum PeriodRailUnit: Equatable {
    case day
    case month
    case year
    /// A span picked by hand walks nowhere. Its two ends were chosen rather
    /// than stepped to, so the rail names them and offers nothing either side:
    /// a run of months through a span nobody asked for in months would invite
    /// a tap that throws the span away.
    case custom(TransactionRange)

    private static let dayTemplate = Date.FormatStyle().day().month(.abbreviated)
    private static let dayYearTemplate = Date.FormatStyle().day().month(.abbreviated).year()
    private static let monthTemplate = Date.FormatStyle().month(.wide)

    /// Months outside this year carry it, so scrolling back never leaves the
    /// owner reading "March" without knowing which March.
    private static let monthYearTemplate = Date.FormatStyle().month(.abbreviated).year()
    private static let yearTemplate = Date.FormatStyle().year()

    /// What a filtered period walks in, which is whatever the header asked for.
    init(range: TransactionRange) {
        switch range.scope {
        case .day:
            self = .day
        case .month:
            self = .month
        case .year:
            self = .year
        case .custom:
            self = .custom(range)
        }
    }

    /// How wide one entry is. A hand-picked span has no unit, so it has none.
    var component: Calendar.Component? {
        switch self {
        case .day:
            .day
        case .month:
            .month
        case .year:
            .year
        case .custom:
            nil
        }
    }

    /// Whether the clock is inside this entry, which is what the rail calls out
    /// in the accent colour. A hand-picked span is never called out: it is the
    /// only entry on the rail, so there is nothing to pick it out from.
    func marksNow(_ period: Date, now: Date = .now) -> Bool {
        guard let component else {
            return false
        }

        return TransactionPeriod.calendar.isDate(period, equalTo: now, toGranularity: component)
    }

    /// The first instant of the period `date` falls in, which is what a rail
    /// entry is named by.
    func start(of date: Date) -> Date {
        switch self {
        case .day:
            TransactionPeriod.calendar.startOfDay(for: date)
        case .month:
            TransactionPeriod.startOfMonth(for: date)
        case .year:
            TransactionPeriod.startOfYear(for: date)
        case .custom(let range):
            range.start
        }
    }

    /// What a tap on an entry asks the header for. A hand-picked span asks for
    /// itself: tapping the only entry cannot be a way to lose it.
    func range(containing date: Date) -> TransactionRange {
        switch self {
        case .day:
            .day(containing: date)
        case .month:
            .month(containing: date)
        case .year:
            .year(containing: date)
        case .custom(let range):
            range
        }
    }

    /// What the entry says. Days and months outside this year carry it; a year
    /// is already unambiguous; a hand-picked span names both its ends, since
    /// neither one alone says what is being added up.
    func label(for period: Date, in locale: Locale, today: Date = .now) -> String {
        let calendar = TransactionPeriod.calendar
        let isThisYear =
            calendar.component(.year, from: period) == calendar.component(.year, from: today)

        let template: Date.FormatStyle

        switch self {
        case .day:
            template = isThisYear ? Self.dayTemplate : Self.dayYearTemplate
        case .month:
            template = isThisYear ? Self.monthTemplate : Self.monthYearTemplate
        case .year:
            template = Self.yearTemplate
        case .custom(let range):
            return range.title(in: locale)
        }

        return TransactionPeriod.format(template, in: locale).format(period)
    }

    /// Spoken in full, since an abbreviation a sighted owner reads in context is
    /// a riddle on its own.
    func accessibilityLabel(for period: Date, in locale: Locale) -> String {
        switch self {
        case .day:
            TransactionPeriod.day(period, in: locale)
        case .month:
            TransactionPeriod.title(for: period, in: locale)
        case .year:
            TransactionPeriod.format(Self.yearTemplate, in: locale).format(period)
        case .custom(let range):
            range.title(in: locale)
        }
    }

    /// Only ever read for an entry the clock is inside, which a hand-picked
    /// span never is.
    var currentPeriodNotice: LocalizedStringKey {
        switch self {
        case .day:
            "Today"
        case .month:
            "Current month"
        case .year:
            "Current year"
        case .custom:
            ""
        }
    }

    /// A stable, sortable name for a period, so a UI test can address one
    /// without depending on how periods are written for people.
    func identifier(for period: Date) -> String {
        let parts = TransactionPeriod.calendar.dateComponents(
            [.year, .month, .day],
            from: period
        )

        switch self {
        case .day:
            return String(
                format: "%04d-%02d-%02d",
                parts.year ?? 0,
                parts.month ?? 0,
                parts.day ?? 0
            )
        case .month:
            return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
        case .year:
            return String(format: "%04d", parts.year ?? 0)
        case .custom(let range):
            return "custom-\(Self.dayIdentifier(range.start))-\(Self.dayIdentifier(range.lastDay))"
        }
    }

    private static func dayIdentifier(_ date: Date) -> String {
        let parts = TransactionPeriod.calendar.dateComponents([.year, .month, .day], from: date)

        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// The entries a rail offers for the period a screen is filtered to, and which
/// of them that period sits on.
///
/// The filter is the authority: a screen showing a year is walked in years, one
/// showing a day in days, and one showing a hand-picked span gets that span
/// alone. The run always covers the period on show, so the entry the figures
/// belong to is never off the end of the rail.
struct PeriodRailPeriods: Equatable {
    let unit: PeriodRailUnit
    let periods: [Date]
    let selection: Date

    init(range: TransactionRange, today: Date) {
        let unit = PeriodRailUnit(range: range)
        let selection = unit.start(of: range.start)
        let first = CalendarTheme.startMonth(from: today)
        let last = CalendarTheme.endMonth(from: today)

        self.unit = unit
        self.selection = selection

        switch unit {
        case .day:
            // Days run into a wall much faster than months do, so the rail is a
            // window around the day on show rather than every day the calendars
            // offer. It re-centres as the owner walks off either end.
            periods = TransactionPeriod.days(
                from: TransactionPeriod.calendar.date(byAdding: .month, value: -1, to: selection)
                    ?? selection,
                through: TransactionPeriod.calendar.date(byAdding: .month, value: 1, to: selection)
                    ?? selection
            )
        case .month:
            periods = TransactionPeriod.months(
                from: min(first, selection),
                through: max(last, selection)
            )
        case .year:
            periods = TransactionPeriod.years(
                from: min(first, selection),
                through: max(last, selection)
            )
        case .custom:
            periods = [selection]
        }
    }
}

/// The run of periods across the top of a screen, with the one on show marked
/// and scrolled to the middle and the one the clock is in called out. It is the
/// fastest way to move a period either way; the fuller pickers stay behind the
/// filter button beside it.
///
/// It owns no period of its own. The screen keeps the range, hands down the
/// unit that range is cut in and the periods to offer, and is told which one was
/// tapped. A screen filtering by year gets years, one filtering by day gets
/// days, so the rail can never describe a wider slice of time than the figures
/// under it.
struct PeriodRail: View {
    @Environment(\.locale) private var locale

    /// The unit each entry stands for. A hand-picked range has no unit of its
    /// own, so the screen picks the one it wants the rail to walk in.
    let unit: PeriodRailUnit
    let periods: [Date]
    /// The period on show. A range narrowed inside one entry still marks that
    /// entry, because the screen hands down the period it falls in.
    let selection: Date
    let onSelect: (Date) -> Void

    /// A scroll view takes every point offered it, and the rail is offered the
    /// whole screen, so its height is stated rather than inferred. It scales
    /// with the text size so a larger type setting is not clipped.
    @ScaledMetric(relativeTo: .subheadline) private var railHeight: CGFloat = 46

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 2) {
                    ForEach(periods, id: \.self) { period in
                        periodButton(period)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
            .scrollDisabled(true)
            .onAppear {
                scroll(to: selection, in: proxy, animated: false)
            }
            .onChange(of: selection) { _, period in
                scroll(to: period, in: proxy, animated: true)
            }
        }
        .frame(height: railHeight)
        .accessibilityIdentifier("period-rail")
    }

    private func periodButton(_ period: Date) -> some View {
        let isSelected = period == selection
        let isCurrent = unit.marksNow(period)

        return Button {
            onSelect(period)
        } label: {
            VStack(spacing: 5) {
                Text(unit.label(for: period, in: locale))
                    .font(
                        .subheadline.weight(
                            isSelected ? .bold : (isCurrent ? .semibold : .medium)
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(
                        isCurrent
                            ? MonMonTheme.accent
                            : (isSelected ? MonMonTheme.textPrimary : MonMonTheme.textMuted)
                    )

                // The period on show keeps a bar under it, so it is marked by
                // more than a weight the eye would have to compare against its
                // neighbours.
                Capsule()
                    .fill(isSelected ? MonMonTheme.accent : Color.clear)
                    .frame(width: 20, height: 3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                isCurrent ? MonMonTheme.accent.opacity(0.14) : Color.clear,
                in: Capsule()
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(period)
        .animation(.snappy(duration: 0.22), value: isSelected)
        .accessibilityLabel(unit.accessibilityLabel(for: period, in: locale))
        .accessibilityValue(isCurrent ? Text(unit.currentPeriodNotice) : Text(""))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("period-rail-\(unit.identifier(for: period))")
    }

    /// Keeps the period on show in the middle, so the ones either side of it are
    /// always the ones within reach.
    private func scroll(to period: Date, in proxy: ScrollViewProxy, animated: Bool) {
        guard periods.contains(period) else {
            return
        }

        guard animated else {
            proxy.scrollTo(period, anchor: .center)
            return
        }

        withAnimation(.snappy(duration: 0.3)) {
            proxy.scrollTo(period, anchor: .center)
        }
    }
}

#if DEBUG
    private struct PeriodRailPreview: View {
        @State private var range = TransactionRange.month(containing: .now)

        var body: some View {
            VStack(spacing: 12) {
                rail(for: range)

                rail(for: .year(containing: .now))

                rail(for: .day(containing: .now))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(MonMonTheme.canvas)
        }

        private func rail(for range: TransactionRange) -> some View {
            let periods = PeriodRailPeriods(range: range, today: .now)

            return PeriodRail(
                unit: periods.unit,
                periods: periods.periods,
                selection: periods.selection
            ) { period in
                self.range = periods.unit.range(containing: period)
            }
        }
    }

    #Preview("Period rail") {
        PeriodRailPreview()
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
