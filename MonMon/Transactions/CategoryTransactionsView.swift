import SwiftData
import SwiftUI

/// Identifies one wedge of the breakdown: a category, a direction, and the
/// stretch of time being looked at. `categoryID` is optional so the transactions
/// whose category was deleted are reachable too.
struct CategoryPeriod: Hashable {
    let categoryID: UUID?
    let kind: TransactionKind
    let range: TransactionRange
}

/// The transactions behind one wedge of the spending doughnut.
struct CategoryTransactionsView: View {
    @Environment(\.locale) private var locale

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    let period: CategoryPeriod

    @State private var editorMode: TransactionEditorMode?

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    summaryCard

                    if matching.isEmpty {
                        emptyState
                    } else {
                        ForEach(matching) { transaction in
                            Button {
                                editorMode = .edit(transaction)
                            } label: {
                                TransactionCard(
                                    transaction: transaction,
                                    category: category(for: transaction),
                                    account: account(for: transaction)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("transaction-\(transaction.id.uuidString)")
                            .accessibilityHint("Opens the transaction editor.")
                        }
                    }
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(categoryName)
        .accessibilityIdentifier("category-transactions")
        .appSheet(item: $editorMode) { mode in
            TransactionEditorView(mode: mode)
        }
        .tint(MonMonTheme.accent)
    }

    /// The same narrowing the card did, repeated here rather than passed along,
    /// so the list stays right when a transaction is edited or deleted from
    /// this very screen.
    private var matching: [MoneyTransaction] {
        CategoryBreakdown.transactions(
            for: period.categoryID,
            of: period.kind,
            in: TransactionSummary.inRange(period.range, transactions: transactions)
        )
    }

    private var selectedCategory: TransactionCategory? {
        guard let categoryID = period.categoryID else {
            return nil
        }

        return categories.first { $0.id == categoryID }
    }

    private var categoryName: String {
        selectedCategory?.name ?? CategoryBreakdown.uncategorizedName
    }

    private var total: Decimal {
        matching.reduce(Decimal.zero) { total, transaction in
            total + transaction.amount
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                period.range.title(in: locale).uppercased(),
                systemImage: period.kind.symbolName
            )
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(MonMonTheme.textSecondary)

            Text("\(period.kind.signLabel)\(VNDCurrency.format(total))")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(MonMonTheme.textPrimary)

            Text(countLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.hero)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.heroBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var countLabel: String {
        AppText.string("\(matching.count) transactions", in: locale)
    }

    private var emptyState: some View {
        Text("Nothing left under this category \(period.range.phrase(in: locale)).")
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                    .fill(MonMonTheme.surface)
            }
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
}
