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
    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    let period: DayPeriod

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
                                    account: account(for: transaction),
                                    showsDate: false
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
        .navigationTitle(Self.titleFormat.format(period.day))
        .accessibilityIdentifier("day-transactions")
        .sheet(item: $editorMode) { mode in
            // A transaction added from a day lands on that day, which is the
            // only day this screen can show.
            TransactionEditorView(mode: mode, defaultDate: period.day)
        }
        .tint(MonMonTheme.accent)
    }

    /// Re-read here rather than handed in, so the list stays right when a
    /// transaction is edited, moved to another day, or deleted from this screen.
    private var matching: [MoneyTransaction] {
        TransactionSummary.inRange(period.range, transactions: transactions)
    }

    private var income: Decimal {
        TransactionSummary.totalIncome(of: matching)
    }

    private var expense: Decimal {
        TransactionSummary.totalExpense(of: matching)
    }

    private var net: Decimal {
        TransactionSummary.net(of: matching)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Self.headerFormat.format(period.day).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(signed(net))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(MonMonTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Label(
                    "Income \(VNDCurrency.format(income))",
                    systemImage: TransactionKind.income.symbolName
                )
                .font(.subheadline.weight(.medium))

                Label(
                    "Expense \(VNDCurrency.format(expense))",
                    systemImage: TransactionKind.expense.symbolName
                )
                .font(.subheadline.weight(.medium))

                Label(countLabel, systemImage: "rectangle.stack.fill")
                    .font(.subheadline.weight(.medium))
            }
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

    /// The sign is written out rather than left to the minus the formatter would
    /// place, so a day that gained reads as clearly as one that lost.
    private func signed(_ amount: Decimal) -> String {
        let magnitude = amount < 0 ? -amount : amount
        let sign = amount < 0 ? "−" : "+"

        return "\(sign)\(VNDCurrency.format(magnitude))"
    }

    private var countLabel: String {
        matching.count == 1 ? "1 transaction" : "\(matching.count) transactions"
    }

    private var emptyState: some View {
        Text("Nothing recorded on this day.")
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

    /// The bar has room for a short date; the card below it spells the day out.
    private static let titleFormat: Date.FormatStyle = {
        var style = Date.FormatStyle().day().month(.abbreviated).year()
        style.calendar = TransactionPeriod.calendar
        style.timeZone = TransactionPeriod.calendar.timeZone
        style.locale = Locale(identifier: "en_US")
        return style
    }()

    private static let headerFormat: Date.FormatStyle = {
        var style = Date.FormatStyle().weekday(.wide).day().month(.wide).year()
        style.calendar = TransactionPeriod.calendar
        style.timeZone = TransactionPeriod.calendar.timeZone
        style.locale = Locale(identifier: "en_US")
        return style
    }()
}
