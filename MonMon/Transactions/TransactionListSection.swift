import SwiftUI

/// The transaction list shared by every transaction-only screen.
///
/// Spending defines the visual language: transactions are grouped by day, the
/// day's net sits in its header, and every row opens details with the same edit
/// and delete gestures. Callers provide only their heading variation and the
/// edit destination.
struct TransactionListSection<Accessory: View>: View {
    @Environment(\.locale) private var locale

    @State private var actions = TransactionActions()

    let title: LocalizedStringKey
    let transactions: [MoneyTransaction]
    let categories: [TransactionCategory]
    let accounts: [CashAccount]
    let emptyNotice: LocalizedStringKey
    let accessibilityIdentifierPrefix: String
    let showsCount: Bool
    let undoBottomInset: CGFloat
    let onEdit: (MoneyTransaction) -> Void
    @ViewBuilder let accessory: Accessory

    init(
        title: LocalizedStringKey,
        transactions: [MoneyTransaction],
        categories: [TransactionCategory],
        accounts: [CashAccount],
        emptyNotice: LocalizedStringKey,
        accessibilityIdentifierPrefix: String = "transaction",
        showsCount: Bool = false,
        undoBottomInset: CGFloat = 20,
        onEdit: @escaping (MoneyTransaction) -> Void,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.transactions = transactions
        self.categories = categories
        self.accounts = accounts
        self.emptyNotice = emptyNotice
        self.accessibilityIdentifierPrefix = accessibilityIdentifierPrefix
        self.showsCount = showsCount
        self.undoBottomInset = undoBottomInset
        self.onEdit = onEdit
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if transactions.isEmpty {
                Text(emptyNotice)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            ForEach(dayGroups) { group in
                VStack(alignment: .leading, spacing: 12) {
                    dayHeader(for: group)

                    ForEach(group.transactions) { transaction in
                        TransactionItem(
                            transaction: transaction,
                            category: category(for: transaction),
                            account: account(for: transaction),
                            showsDate: false,
                            accessibilityIdentifier:
                                "\(accessibilityIdentifierPrefix)-\(transaction.id.uuidString)"
                        )
                    }
                }
            }
        }
        .transactionActions(
            actions,
            undoBottomInset: undoBottomInset,
            category: category(for:),
            account: account(for:),
            onEdit: onEdit
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if showsCount {
                Text(transactions.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.accent.opacity(0.16), in: Capsule())
            }

            Spacer(minLength: 8)

            accessory
        }
    }

    private var dayGroups: [TransactionDayGroup] {
        TransactionSummary.byDay(transactions)
    }

    private func dayHeader(for group: TransactionDayGroup) -> some View {
        HStack(spacing: 12) {
            Text(
                TransactionPeriod.format(Self.dayTemplate, in: locale).format(group.day)
                    .uppercased()
            )
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Text(signed(group.net))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(MonMonTheme.textSecondary)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private func signed(_ amount: Decimal) -> String {
        let magnitude = amount < 0 ? -amount : amount
        let sign = amount < 0 ? "−" : "+"

        return "\(sign)\(VNDCurrency.format(magnitude))"
    }

    private func category(for transaction: MoneyTransaction) -> TransactionCategory? {
        guard let categoryID = transaction.categoryID else {
            return nil
        }

        return categories.first { $0.id == categoryID }
    }

    private func account(for transaction: MoneyTransaction) -> CashAccount? {
        accounts.first { $0.id == transaction.accountID }
    }

    private static var dayTemplate: Date.FormatStyle {
        Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
    }
}

extension TransactionListSection where Accessory == EmptyView {
    init(
        title: LocalizedStringKey = "Transactions",
        transactions: [MoneyTransaction],
        categories: [TransactionCategory],
        accounts: [CashAccount],
        emptyNotice: LocalizedStringKey,
        accessibilityIdentifierPrefix: String = "transaction",
        showsCount: Bool = false,
        undoBottomInset: CGFloat = 20,
        onEdit: @escaping (MoneyTransaction) -> Void
    ) {
        self.init(
            title: title,
            transactions: transactions,
            categories: categories,
            accounts: accounts,
            emptyNotice: emptyNotice,
            accessibilityIdentifierPrefix: accessibilityIdentifierPrefix,
            showsCount: showsCount,
            undoBottomInset: undoBottomInset,
            onEdit: onEdit
        ) {
            EmptyView()
        }
    }
}
