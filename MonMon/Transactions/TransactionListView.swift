import SwiftData
import SwiftUI

struct TransactionListView: View {
    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @State private var range = TransactionRange.month(containing: .now)
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
                        periodCard

                        if accounts.isEmpty {
                            noAccountState
                        } else if visibleTransactions.isEmpty {
                            emptyState
                        } else {
                            CategoryBreakdownCard(
                                kind: $breakdownKind,
                                slices: breakdownSlices,
                                range: range
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

    /// Adding from a period that does not include today starts on its first
    /// day, so the new entry lands where the owner is looking.
    private var defaultDate: Date {
        range.contains(.now) ? .now : range.start
    }

    /// The anchor a scope change re-cuts around: today when it is on show, and
    /// otherwise the start of what is, so the owner keeps their place.
    private var anchor: Date {
        range.contains(.now) ? .now : range.start
    }

    private var visibleTransactions: [MoneyTransaction] {
        TransactionSummary.inRange(range, transactions: transactions)
    }

    private var breakdownSlices: [CategoryBreakdownSlice] {
        CategoryBreakdown.slices(
            of: breakdownKind,
            transactions: visibleTransactions,
            categories: categories
        )
    }

    private var periodCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            scopePicker

            periodHeader

            if range.scope == .custom {
                customRangeFields
            }

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

    /// Switching scope keeps the owner near what they were looking at, so a
    /// month spent browsing last March narrows to a day in last March rather
    /// than jumping to today.
    private var scopeSelection: Binding<TransactionRangeScope> {
        Binding(
            get: { range.scope },
            set: { range = range.scoped(to: $0, anchoredOn: anchor) }
        )
    }

    private var scopePicker: some View {
        Picker("Period", selection: scopeSelection) {
            ForEach(TransactionRangeScope.allCases) {
                Text($0.displayName)
                    .tag($0)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("period-scope")
    }

    private var periodHeader: some View {
        HStack(spacing: 12) {
            if range.canStep {
                stepButton(by: -1, symbolName: "chevron.left", identifier: "previous-period")
            }

            Text(range.title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(MonMonTheme.textSecondary)
                .frame(maxWidth: .infinity)

            if range.canStep {
                stepButton(by: 1, symbolName: "chevron.right", identifier: "next-period")
            }
        }
    }

    private func stepButton(by steps: Int, symbolName: String, identifier: String) -> some View {
        Button {
            range = range.stepped(by: steps)
        } label: {
            Image(systemName: symbolName)
                .font(.footnote.weight(.bold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .background(MonMonTheme.surface, in: Circle())
        .accessibilityLabel(steps < 0 ? range.stepBackLabel : range.stepForwardLabel)
        .accessibilityIdentifier(identifier)
    }

    /// The two ends of a hand-picked range. `TransactionRange.custom` orders the
    /// pair, so picking an end before the start reads as the range the owner
    /// drew rather than an empty one.
    private var customRangeFields: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 12) {
                rangeEndField(title: "From", selection: rangeStart, identifier: "range-start")
                rangeEndField(title: "To", selection: rangeEnd, identifier: "range-end")
            }

            VStack(alignment: .leading, spacing: 12) {
                rangeEndField(title: "From", selection: rangeStart, identifier: "range-start")
                rangeEndField(title: "To", selection: rangeEnd, identifier: "range-end")
            }
        }
    }

    private func rangeEndField(
        title: String,
        selection: Binding<Date>,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(MonMonTheme.textSecondary)

            DateField(selection: selection, accessibilityIdentifier: identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rangeStart: Binding<Date> {
        Binding(
            get: { range.start },
            set: { range = .custom(from: $0, to: range.lastDay) }
        )
    }

    private var rangeEnd: Binding<Date> {
        Binding(
            get: { range.lastDay },
            set: { range = .custom(from: range.start, to: $0) }
        )
    }

    private var income: Decimal {
        TransactionSummary.totalIncome(of: visibleTransactions)
    }

    private var expense: Decimal {
        TransactionSummary.totalExpense(of: visibleTransactions)
    }

    private var net: Decimal {
        TransactionSummary.net(of: visibleTransactions)
    }

    /// The sign is written out rather than left to the minus the formatter would
    /// place, so a surplus reads as clearly as a shortfall.
    private var signedNet: String {
        let magnitude = net < 0 ? -net : net
        let sign = net < 0 ? "−" : "+"

        return "\(sign)\(VNDCurrency.format(magnitude))"
    }

    private var countLabel: String {
        switch visibleTransactions.count {
        case 0:
            "Nothing recorded \(range.phrase)"
        case 1:
            "1 transaction"
        default:
            "\(visibleTransactions.count) transactions"
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

            ForEach(visibleTransactions) { transaction in
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
            message: "Record what you spent or received and this period adds up."
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
