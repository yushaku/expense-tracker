import SwiftUI

/// The run of months across the top of a screen, with the one on show marked
/// and scrolled to the middle. It is the fastest way to move a month either
/// way; the fuller pickers stay behind the filter button beside it.
///
/// It owns no period of its own. The screen keeps the range, hands down the
/// month it is showing, and is told which month was tapped.
struct MonthRail: View {
    @Environment(\.locale) private var locale

    let months: [Date]
    /// The month on show. A period narrowed to one day inside a month still
    /// marks that month, because the screen hands down the month it falls in.
    let selection: Date
    let onSelect: (Date) -> Void

    /// A scroll view takes every point offered it, and the rail is offered the
    /// whole screen, so its height is stated rather than inferred. It scales
    /// with the text size so a larger type setting is not clipped.
    @ScaledMetric(relativeTo: .subheadline) private var railHeight: CGFloat = 46

    private static let monthTemplate = Date.FormatStyle().month(.wide)

    /// Months outside this year carry it, so scrolling back never leaves the
    /// owner reading "March" without knowing which March.
    private static let monthYearTemplate = Date.FormatStyle().month(.abbreviated).year()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 2) {
                    ForEach(months, id: \.self) { month in
                        monthButton(month)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
            .onAppear {
                scroll(to: selection, in: proxy, animated: false)
            }
            .onChange(of: selection) { _, month in
                scroll(to: month, in: proxy, animated: true)
            }
        }
        .frame(height: railHeight)
        .accessibilityIdentifier("month-rail")
    }

    private func monthButton(_ month: Date) -> some View {
        let isSelected = month == selection

        return Button {
            onSelect(month)
        } label: {
            VStack(spacing: 5) {
                Text(label(for: month))
                    .font(.subheadline.weight(isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .foregroundStyle(
                        isSelected ? MonMonTheme.textPrimary : MonMonTheme.textMuted
                    )

                // The month on show keeps a bar under it, so it is marked by
                // more than a weight the eye would have to compare against its
                // neighbours.
                Capsule()
                    .fill(isSelected ? MonMonTheme.accent : Color.clear)
                    .frame(width: 20, height: 3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(month)
        .animation(.snappy(duration: 0.22), value: isSelected)
        .accessibilityLabel(TransactionPeriod.title(for: month, in: locale))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("month-rail-\(identifier(month))")
    }

    private func label(for month: Date) -> String {
        let calendar = TransactionPeriod.calendar
        let isThisYear =
            calendar.component(.year, from: month) == calendar.component(.year, from: .now)

        let template = isThisYear ? Self.monthTemplate : Self.monthYearTemplate

        return TransactionPeriod.format(template, in: locale).format(month)
    }

    /// Keeps the month on show in the middle, so the months either side of it
    /// are always the ones within reach.
    private func scroll(to month: Date, in proxy: ScrollViewProxy, animated: Bool) {
        guard months.contains(month) else {
            return
        }

        guard animated else {
            proxy.scrollTo(month, anchor: .center)
            return
        }

        withAnimation(.snappy(duration: 0.3)) {
            proxy.scrollTo(month, anchor: .center)
        }
    }

    /// A stable, sortable name for a month, so a UI test can address one without
    /// depending on how months are written for people.
    private func identifier(_ month: Date) -> String {
        let components = TransactionPeriod.calendar.dateComponents([.year, .month], from: month)

        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }
}

#if DEBUG
    private struct MonthRailPreview: View {
        @State private var range = TransactionRange.month(containing: .now)

        var body: some View {
            MonthRail(
                months: TransactionPeriod.months(
                    from: CalendarTheme.startMonth(),
                    through: CalendarTheme.endMonth()
                ),
                selection: TransactionPeriod.startOfMonth(for: range.start)
            ) { month in
                range = .month(containing: month)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(MonMonTheme.canvas)
        }
    }

    #Preview("Month rail") {
        MonthRailPreview()
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
