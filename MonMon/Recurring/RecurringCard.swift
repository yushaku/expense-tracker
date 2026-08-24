import SwiftUI

/// One rule as a row: what it records, how often, and when it next falls due.
struct RecurringCard: View {
    let rule: RecurringRule
    let category: TransactionCategory?
    let account: CashAccount?
    let asOf: Date

    private static let dateFormat: Date.FormatStyle = {
        var style = Date.FormatStyle().day().month(.abbreviated)
        style.calendar = TransactionPeriod.calendar
        style.timeZone = TransactionPeriod.calendar.timeZone
        style.locale = Locale(identifier: "en_US")
        return style
    }()

    var body: some View {
        HStack(spacing: 14) {
            icon

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            amount
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        // A paused rule is still a rule the owner wrote, so it is dimmed rather
        // than hidden or restyled into something else.
        .opacity(rule.isPaused ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }

    private var icon: some View {
        Image(systemName: symbolName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))
            .accessibilityHidden(true)
    }

    private var amount: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text("\(rule.kind.signLabel)\(VNDCurrency.format(rule.amount))")
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(directionTint)

            Label(dueLabel, systemImage: dueSymbolName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MonMonTheme.textSecondary)
        }
    }

    /// The note names the rule — "Rent" — and the category stands in when the
    /// owner left it blank.
    private var title: String {
        let trimmedNote = rule.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNote.isEmpty else {
            return trimmedNote
        }

        return category?.name ?? CategoryBreakdown.uncategorizedName
    }

    private var subtitle: String {
        let accountName = account?.name ?? "Unknown account"
        return "\(rule.schedulePhrase) · \(accountName)"
    }

    /// A rule that will never fall due again says so, rather than showing a date
    /// that is not coming.
    private var dueLabel: String {
        guard !rule.isPaused else {
            return "Paused"
        }

        guard let next = rule.nextOccurrence(after: asOf) else {
            return "Finished"
        }

        return "Next \(Self.dateFormat.format(next))"
    }

    private var dueSymbolName: String {
        if rule.isPaused {
            return "pause.fill"
        }

        return rule.nextOccurrence(after: asOf) == nil
            ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
    }

    private var symbolName: String {
        guard let category else {
            return rule.frequency.symbolName
        }

        return CategoryPalette.symbolName(category.symbolName)
    }

    private var tint: Color {
        guard let category else {
            return MonMonTheme.textMuted
        }

        return CategoryPalette.color(named: category.colorName)
    }

    private var directionTint: Color {
        rule.kind == .income ? MonMonTheme.gain : MonMonTheme.textPrimary
    }
}
