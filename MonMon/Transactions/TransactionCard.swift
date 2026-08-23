import SwiftUI

struct TransactionCard: View {
    let transaction: MoneyTransaction
    let category: TransactionCategory?
    let account: CashAccount?

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
                Text(categoryName)
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
            // The sign carries the direction; colour only reinforces it.
            Text("\(transaction.kind.signLabel)\(VNDCurrency.format(transaction.amount))")
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(directionTint)

            Label(
                Self.dateFormat.format(transaction.occurredAt),
                systemImage: transaction.kind.symbolName
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(MonMonTheme.textSecondary)
        }
    }

    private var categoryName: String {
        category?.name ?? "Uncategorized"
    }

    private var subtitle: String {
        let accountName = account?.name ?? "Unknown account"
        let trimmedNote = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedNote.isEmpty ? accountName : "\(accountName) · \(trimmedNote)"
    }

    private var symbolName: String {
        guard let category else {
            return transaction.kind.symbolName
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
        transaction.kind == .income ? MonMonTheme.gain : MonMonTheme.textPrimary
    }
}
