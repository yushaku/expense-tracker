import SwiftData
import SwiftUI

/// One day of the spending calendar. A whole day rather than a date so the
/// screen it opens can filter by the same half-open range everything else uses.
struct DayPeriod: Hashable {
    let day: Date

    var range: TransactionRange {
        .day(containing: day)
    }
}

/// What one day of the month calendar was made of: what came in, what went out,
/// and every transaction behind those two figures.
struct DayTransactionsView: View {
    @Environment(\.appDateFormat) private var dateFormat

    @Environment(\.locale) private var locale

    /// Only the day on show is fetched. The whole ledger used to be read and
    /// filtered on every update, including the ones a sheet or a swipe causes.
    @Query private var transactions: [MoneyTransaction]

    @Query private var transfers: [AccountTransfer]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    let period: DayPeriod

    @State private var editorMode: TransactionEditorMode?
    @State private var transactionActions = TransactionActions()

    init(period: DayPeriod) {
        self.period = period
        _transactions = Query(LedgerFetch.transactions(in: period.range))
        _transfers = Query(LedgerFetch.transfers(in: period.range))
    }

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    SpendingOverviewCard(
                        title: dateFormat.format(period.day),
                        income: income,
                        expense: expense,
                        count: matching.count + matchingTransfers.count
                    )

                    TransactionListSection(
                        transactions: matching,
                        transfers: matchingTransfers,
                        categories: categories,
                        accounts: accounts,
                        emptyNotice: "Nothing recorded on this day."
                    )
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, FloatingAddButton.contentInset)
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !accounts.isEmpty {
                FloatingAddButton(
                    title: "Add Transaction",
                    accessibilityIdentifier: "add-transaction"
                ) {
                    editorMode = .add
                }
            }
        }
        .navigationTitle(
            dateFormat.format(period.day)
        )
        .accessibilityIdentifier("day-transactions")
        .appSheet(item: $editorMode) { mode in
            // A transaction added from a day lands on that day, which is the
            // only day this screen can show.
            TransactionEditorView(mode: mode, defaultDate: period.day)
        }
        .transactionActions(
            transactionActions,
            undoBottomInset: FloatingAddButton.contentInset,
            category: category(for:),
            account: account(for:),
            onEdit: { editorMode = .edit($0) }
        )
        .tint(MonMonTheme.accent)
    }

    /// Re-read here rather than handed in, so the list stays right when a
    /// transaction is edited, moved to another day, or deleted from this screen.
    private var matching: [MoneyTransaction] {
        TransactionSummary.inRange(period.range, transactions: transactions)
    }

    private var matchingTransfers: [AccountTransfer] {
        transfers.filter { period.range.contains($0.occurredAt) }
    }

    private var income: Decimal {
        TransactionSummary.totalIncome(of: matching)
    }

    private var expense: Decimal {
        TransactionSummary.totalExpense(of: matching)
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
