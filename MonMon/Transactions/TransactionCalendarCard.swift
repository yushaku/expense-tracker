import SwiftUI

/// A month at a glance: every day carries what it took in and what it paid out,
/// and tapping one opens that day's transactions.
///
/// The card owns no month of its own. The screen keeps the selected month, so
/// stepping the calendar also updates the totals around it.
struct TransactionCalendarCard: View {
    let month: Date
    let weeks: [TransactionCalendarWeek]
    /// Steps the month by ±1. Handed out rather than done here so the screen's
    /// selection and this grid can never disagree about which month is on show.
    let onStepMonth: (Int) -> Void

    @Environment(\.locale) private var locale

    private static let dayNumberTemplate = Date.FormatStyle().day()
    private static let dayLabelTemplate = Date.FormatStyle().weekday(.abbreviated).day()
        .month(.abbreviated)

    /// Column headings in the language on show, rotated to start on the
    /// calendar's own first weekday. The weekday a week starts on is the app's
    /// own, not the language's, so the columns never shift under the grid.
    private static func weekdaySymbols(in locale: Locale) -> [String] {
        var calendar = TransactionPeriod.calendar
        calendar.locale = locale

        let symbols = calendar.veryShortWeekdaySymbols
        let first = min(max(TransactionPeriod.calendar.firstWeekday - 1, 0), symbols.count - 1)

        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            weekdayHeader

            VStack(spacing: 4) {
                ForEach(weeks) { week in
                    HStack(spacing: 4) {
                        ForEach(week.days) { day in
                            dayCell(day)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityIdentifier("transaction-calendar")
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(TransactionPeriod.title(for: month, in: locale).uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(totalsLabel)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(MonMonTheme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            stepButton(-1, systemImage: "chevron.left", label: "Previous month")
            stepButton(1, systemImage: "chevron.right", label: "Next month")
        }
    }

    private var totals: (income: Decimal, expense: Decimal) {
        TransactionCalendar.monthTotals(of: weeks)
    }

    private var totalsLabel: LocalizedStringKey {
        let totals = totals

        return "+\(VNDCurrency.format(totals.income))  −\(VNDCurrency.format(totals.expense))"
    }

    private func stepButton(
        _ steps: Int,
        systemImage: String,
        label: String
    ) -> some View {
        Button {
            onStepMonth(steps)
        } label: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.bold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 30, height: 30)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("calendar-\(steps < 0 ? "previous" : "next")-month")
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Self.weekdaySymbols(in: locale), id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// A day is a link even when it recorded nothing: an empty day still answers
    /// "what did I spend then", and days that only sometimes take a tap make the
    /// grid feel broken.
    private func dayCell(_ day: TransactionCalendarDay) -> some View {
        NavigationLink(value: DayPeriod(day: day.date)) {
            VStack(spacing: 2) {
                Text(TransactionPeriod.format(Self.dayNumberTemplate, in: locale).format(day.date))
                    .font(.caption2.weight(isToday(day) ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(numberColor(day))

                // Only what moved is written. A day with nothing on it stays
                // blank rather than carrying two zeroes, so the days that did
                // something are what the eye lands on.
                VStack(spacing: 1) {
                    if day.income > 0 {
                        amountLabel("+\(VNDCurrency.format(day.income))", tint: MonMonTheme.gain)
                    }

                    if day.expense > 0 {
                        amountLabel(
                            "−\(VNDCurrency.format(day.expense))",
                            tint: MonMonTheme.danger
                        )
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(day.isEmpty ? Color.clear : MonMonTheme.field.opacity(0.7))
            }
            .overlay {
                if isToday(day) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(MonMonTheme.accent.opacity(0.55), lineWidth: 1.5)
                }
            }
            .opacity(day.isInMonth ? 1 : 0.35)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(day))
        .accessibilityHint("Opens this day's transactions.")
        .accessibilityIdentifier("calendar-day-\(dayIdentifier(day))")
    }

    private func amountLabel(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(tint)
    }

    private func numberColor(_ day: TransactionCalendarDay) -> Color {
        isToday(day) ? MonMonTheme.accent : MonMonTheme.textPrimary
    }

    private func isToday(_ day: TransactionCalendarDay) -> Bool {
        TransactionPeriod.calendar.isDate(day.date, inSameDayAs: .now)
    }

    private func accessibilityLabel(_ day: TransactionCalendarDay) -> String {
        let date = TransactionPeriod.format(Self.dayLabelTemplate, in: locale).format(day.date)

        guard !day.isEmpty else {
            return "\(date), nothing recorded"
        }

        var parts: [String] = [date]

        if day.income > 0 {
            parts.append("income \(VNDCurrency.format(day.income))")
        }

        if day.expense > 0 {
            parts.append("expense \(VNDCurrency.format(day.expense))")
        }

        return parts.joined(separator: ", ")
    }

    /// A stable, sortable name for a day, so a UI test can address one without
    /// depending on how dates are formatted for people.
    private func dayIdentifier(_ day: TransactionCalendarDay) -> String {
        let calendar = TransactionPeriod.calendar
        let components = calendar.dateComponents([.year, .month, .day], from: day.date)

        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
