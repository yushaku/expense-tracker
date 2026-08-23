import SwiftData
import SwiftUI

struct TransactionListView: View {
    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @State private var visibleMonth = TransactionPeriod.startOfMonth(for: .now)
    @State private var editorMode: TransactionEditorMode?
    @State private var breakdownKind: TransactionKind = .expense
    @State private var isManagingCategories = false

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        monthCard

                        if accounts.isEmpty {
                            noAccountState
                        } else if monthTransactions.isEmpty {
                            emptyState
                        } else {
                            CategoryBreakdownCard(
                                kind: $breakdownKind,
                                slices: breakdownSlices,
                                month: visibleMonth
                            )

                            transactionsSection
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
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
            .navigationDestination(for: CategoryPeriod.self) { period in
                CategoryTransactionsView(period: period)
            }
            .navigationTitle("Spending")
            .accessibilityIdentifier("spending-list")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Categories", systemImage: "tag.fill") {
                        isManagingCategories = true
                    }
                    .accessibilityIdentifier("manage-categories")
                }

            }
            .sheet(item: $editorMode) { mode in
                TransactionEditorView(mode: mode, defaultDate: defaultDate)
            }
            .sheet(isPresented: $isManagingCategories) {
                CategoryListView()
            }
            .tint(MonMonTheme.accent)
        }
    }

    /// Adding from a month other than the current one starts on the first of the
    /// month being looked at, so the new entry lands where the owner is looking.
    private var defaultDate: Date {
        TransactionPeriod.contains(.now, monthOf: visibleMonth) ? .now : visibleMonth
    }

    private var monthTransactions: [MoneyTransaction] {
        TransactionSummary.inMonth(of: visibleMonth, transactions: transactions)
    }

    private var breakdownSlices: [CategoryBreakdownSlice] {
        CategoryBreakdown.slices(
            of: breakdownKind,
            transactions: monthTransactions,
            categories: categories
        )
    }

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            monthHeader

            Text(signedNet)
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
    }

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Button {
                visibleMonth = TransactionPeriod.shift(visibleMonth, byMonths: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.footnote.weight(.bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .background(MonMonTheme.surface, in: Circle())
            .accessibilityLabel("Previous month")
            .accessibilityIdentifier("previous-month")

            Text(TransactionPeriod.title(for: visibleMonth).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)
                .frame(maxWidth: .infinity)

            Button {
                visibleMonth = TransactionPeriod.shift(visibleMonth, byMonths: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .background(MonMonTheme.surface, in: Circle())
            .accessibilityLabel("Next month")
            .accessibilityIdentifier("next-month")
        }
    }

    private var income: Decimal {
        TransactionSummary.totalIncome(of: monthTransactions)
    }

    private var expense: Decimal {
        TransactionSummary.totalExpense(of: monthTransactions)
    }

    private var net: Decimal {
        TransactionSummary.net(of: monthTransactions)
    }

    /// The sign is written out rather than left to the minus the formatter would
    /// place, so a surplus reads as clearly as a shortfall.
    private var signedNet: String {
        let magnitude = net < 0 ? -net : net
        let sign = net < 0 ? "−" : "+"

        return "\(sign)\(VNDCurrency.format(magnitude))"
    }

    private var countLabel: String {
        switch monthTransactions.count {
        case 0:
            "Nothing recorded this month"
        case 1:
            "1 transaction"
        default:
            "\(monthTransactions.count) transactions"
        }
    }

    private var addTransactionButton: some View {
        Button("Add Transaction", systemImage: "plus") {
            editorMode = .add
        }
        .accessibilityIdentifier("add-transaction")
    }

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transactions")
                .font(.title3.weight(.semibold))

            ForEach(monthTransactions) { transaction in
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

    private func category(for transaction: MoneyTransaction) -> TransactionCategory? {
        guard let categoryID = transaction.categoryID else {
            return nil
        }

        return categories.first { $0.id == categoryID }
    }

    private func account(for transaction: MoneyTransaction) -> CashAccount? {
        accounts.first { $0.id == transaction.accountID }
    }

    private var emptyState: some View {
        placeholder(
            symbolName: "arrow.left.arrow.right",
            title: "Nothing here yet",
            message: "Record what you spent or received and this month adds up."
        ) {
            addTransactionButton
        }
    }

    private var noAccountState: some View {
        placeholder(
            symbolName: "wallet.bifold.fill",
            title: "Add an account first",
            message: "Every transaction moves one account, so there has to be one to move."
        ) {
            EmptyView()
        }
    }

    private func placeholder<Action: View>(
        symbolName: String,
        title: String,
        message: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: symbolName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            action()
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }
}
