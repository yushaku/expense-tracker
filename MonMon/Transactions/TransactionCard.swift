import SwiftUI

struct TransactionCard: View {
    let transaction: MoneyTransaction
    let category: TransactionCategory?
    let account: CashAccount?
    var tripName: String? = nil
    /// The shared transaction list puts one date over each day of cards, so
    /// the card drops its own copy there and keeps it everywhere else.
    var showsDate = true

    var body: some View {
        TransactionCardContent(
            kind: transaction.kind,
            amount: transaction.amount,
            occurredAt: transaction.occurredAt,
            note: transaction.note,
            category: category,
            account: account,
            tripName: tripName,
            showsDate: showsDate,
            isRecurring: transaction.sourceRuleID != nil
        )
    }
}

/// Shared appearance for saved transactions and captures awaiting review.
/// A capture can have no amount yet; it must not look like a zero-value transaction.
struct TransactionCardContent: View {
    @Environment(\.appDateFormat) private var dateFormat
    @Environment(\.locale) private var locale

    let kind: TransactionKind
    let amount: Decimal?
    let occurredAt: Date
    let note: String
    let category: TransactionCategory?
    let account: CashAccount?
    var tripName: String? = nil
    var showsDate = true
    var isRecurring = false

    var body: some View {
        HStack(spacing: 14) {
            icon

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(categoryName)
                        .font(.headline)
                        .lineLimit(1)

                    // Marks what a rule recorded, so an entry the owner does not
                    // remember typing is explained rather than suspicious.
                    if isRecurring {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(MonMonTheme.textSecondary)
                            .accessibilityLabel("Recurring")
                    }
                }

                HStack(spacing: 6) {
                    Label(accountName, systemImage: "wallet.bifold")
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MonMonTheme.textSecondary.opacity(0.12), in: Capsule())
                        .accessibilityLabel("Account: \(accountName)")

                    if let tripName {
                        Label(tripName, systemImage: "airplane")
                            .foregroundStyle(MonMonTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(MonMonTheme.accent.opacity(0.14), in: Capsule())
                            .accessibilityLabel("Trip: \(tripName)")
                    }
                }
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .labelStyle(.titleAndIcon)

                if !displayNote.isEmpty {
                    Text(displayNote)
                        .font(.subheadline)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            amountLabel
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

    private var amountLabel: some View {
        VStack(alignment: .trailing, spacing: 3) {
            // The sign carries the direction; colour only reinforces it.
            Text(amountText)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(directionTint)

            Label(
                showsDate
                    ? dateFormat.format(occurredAt)
                    : kind.displayName(in: locale),
                systemImage: kind.symbolName
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(MonMonTheme.textSecondary)
        }
    }

    private var amountText: String {
        guard let amount else {
            return AppText.string("Amount missing", in: locale)
        }
        return "\(kind.signLabel)\(VNDCurrency.format(amount))"
    }

    private var categoryName: String {
        category?.name ?? AppText.string("Uncategorized", in: locale)
    }

    private var accountName: String {
        account?.name ?? AppText.string("Unknown account", in: locale)
    }

    private var displayNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var symbolName: String {
        guard let category else {
            return kind.symbolName
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
        kind == .income ? MonMonTheme.gain : MonMonTheme.textPrimary
    }
}
