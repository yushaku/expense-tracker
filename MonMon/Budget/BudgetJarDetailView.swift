import SwiftData
import SwiftUI

struct BudgetJarDetailView: View {
    @Environment(\.locale) private var locale

    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    /// Only the month this screen is about; the activity reads no other.
    @Query private var transactions: [MoneyTransaction]

    @Query(sort: \SavingsDeposit.openedAt, order: .reverse)
    private var savingsDeposits: [SavingsDeposit]

    @Query(sort: \SavingsWithdrawal.withdrawnAt, order: .reverse)
    private var savingsWithdrawals: [SavingsWithdrawal]

    @Query(sort: \FundHolding.createdAt, order: .reverse)
    private var fundHoldings: [FundHolding]

    @Query(sort: \FundInstrument.createdAt, order: .forward)
    private var fundInstruments: [FundInstrument]

    @Query(sort: \FundSale.soldAt, order: .reverse)
    private var fundSales: [FundSale]

    let row: BudgetJarSnapshot
    let month: Date
    let asOf: Date

    init(row: BudgetJarSnapshot, month: Date, asOf: Date) {
        self.row = row
        self.month = month
        self.asOf = asOf
        _transactions = Query(LedgerFetch.transactions(in: .month(containing: month)))
    }

    @State private var editorMode: TransactionEditorMode?
    @State private var transactionActions = TransactionActions()

    var body: some View {
        let currentActivity = activity
        let lookup = Lookup(
            categories: categories, accounts: accounts,
            instruments: fundInstruments, sales: fundSales)

        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    Label(
                        TransactionPeriod.title(for: month, in: locale),
                        systemImage: "calendar"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textSecondary)

                    BudgetJarCard(row: row)

                    if currentActivity.isEmpty {
                        emptyState
                    } else {
                        transactionSection(currentActivity)
                        savingsSection(currentActivity, lookup: lookup)
                        fundsSection(currentActivity, lookup: lookup)
                    }
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(row.name)
        .appSheet(item: $editorMode) { mode in
            TransactionEditorView(mode: mode)
        }
        .transactionActions(
            transactionActions,
            category: lookup.category(for:),
            account: lookup.account(for:),
            onEdit: { editorMode = .edit($0) }
        )
        .tint(MonMonTheme.accent)
        .accessibilityIdentifier("budget-jar-detail")
    }

    private var jar: BudgetJar? {
        jars.first { $0.id == row.jarID }
    }

    private var activity: BudgetJarActivitySnapshot {
        guard let jar else {
            return BudgetJarActivitySnapshot(
                transactions: [],
                savingsDeposits: [],
                fundHoldings: []
            )
        }

        return BudgetJarActivity.snapshot(
            for: jar,
            monthContaining: month,
            asOf: asOf,
            jars: jars,
            categories: categories,
            transactions: transactions,
            savingsDeposits: savingsDeposits,
            fundHoldings: fundHoldings
        )
    }

    @ViewBuilder
    private func transactionSection(_ activity: BudgetJarActivitySnapshot) -> some View {
        if !activity.transactions.isEmpty {
            TransactionListSection(
                transactions: activity.transactions,
                categories: categories,
                accounts: accounts,
                emptyNotice: "No transactions assigned to this jar this month.",
                accessibilityIdentifierPrefix: "budget-transaction",
                showsCount: true
            )
        }
    }

    @ViewBuilder
    private func savingsSection(_ activity: BudgetJarActivitySnapshot, lookup: Lookup)
        -> some View
    {
        if !activity.savingsDeposits.isEmpty {
            activitySection("Savings", count: activity.savingsDeposits.count)

            ForEach(activity.savingsDeposits) { deposit in
                SavingsDepositCard(
                    deposit: deposit,
                    sourceAccountName: deposit.sourceAccountID.flatMap(lookup.accountName),
                    withdrawals: savingsWithdrawals,
                    asOf: asOf
                )
            }
        }
    }

    @ViewBuilder
    private func fundsSection(_ activity: BudgetJarActivitySnapshot, lookup: Lookup)
        -> some View
    {
        if !activity.fundHoldings.isEmpty {
            activitySection("Funds & gold", count: activity.fundHoldings.count)

            ForEach(activity.fundHoldings) { holding in
                FundHoldingCard(
                    holding: holding,
                    instrument: lookup.instrument(for: holding),
                    sales: lookup.sales(for: holding),
                    sourceAccountName: holding.sourceAccountID.flatMap(lookup.accountName),
                    asOf: asOf
                )
            }
        }
    }

    private func activitySection(_ title: LocalizedStringKey, count: Int) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))

            Text(count.formatted())
                .font(.caption.weight(.bold))
                .foregroundStyle(MonMonTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MonMonTheme.accent.opacity(0.16), in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No activity this month",
            systemImage: "tray",
            description: Text("Transactions assigned to this jar will appear here.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    /// Categories, accounts, instruments and sales by id, built once per
    /// update instead of a linear search for every row.
    private struct Lookup {
        let categoriesByID: [UUID: TransactionCategory]
        let accountsByID: [UUID: CashAccount]
        let instrumentsByID: [UUID: FundInstrument]
        let salesByHolding: [UUID: [FundSale]]

        init(
            categories: [TransactionCategory], accounts: [CashAccount],
            instruments: [FundInstrument], sales: [FundSale]
        ) {
            categoriesByID = Dictionary(firstWins: categories.map { ($0.id, $0) })
            accountsByID = Dictionary(firstWins: accounts.map { ($0.id, $0) })
            instrumentsByID = Dictionary(firstWins: instruments.map { ($0.id, $0) })
            var salesByHolding: [UUID: [FundSale]] = [:]
            for sale in sales {
                if let holdingID = sale.holdingID {
                    salesByHolding[holdingID, default: []].append(sale)
                }
            }
            self.salesByHolding = salesByHolding
        }

        func category(for transaction: MoneyTransaction) -> TransactionCategory? {
            transaction.categoryID.flatMap { categoriesByID[$0] }
        }

        func account(for transaction: MoneyTransaction) -> CashAccount? {
            accountsByID[transaction.accountID]
        }

        func accountName(_ id: UUID) -> String? {
            accountsByID[id]?.name
        }

        func instrument(for holding: FundHolding) -> FundInstrument? {
            holding.instrumentID.flatMap { instrumentsByID[$0] }
        }

        func sales(for holding: FundHolding) -> [FundSale] {
            salesByHolding[holding.id] ?? []
        }
    }
}
