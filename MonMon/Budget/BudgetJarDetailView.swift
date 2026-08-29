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

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

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

    @Query(sort: \TripWorkspace.startedAt, order: .reverse)
    private var tripWorkspaces: [TripWorkspace]

    let row: BudgetJarSnapshot
    let month: Date
    let asOf: Date

    var body: some View {
        let currentActivity = activity

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
                        savingsSection(currentActivity)
                        fundsSection(currentActivity)
                    }
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(row.name)
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
            activitySection("Transactions", count: activity.transactions.count)

            ForEach(activity.transactions) { transaction in
                TransactionCard(
                    transaction: transaction,
                    category: category(for: transaction),
                    account: account(transaction.accountID),
                    tripName: tripName(for: transaction)
                )
            }
        }
    }

    @ViewBuilder
    private func savingsSection(_ activity: BudgetJarActivitySnapshot) -> some View {
        if !activity.savingsDeposits.isEmpty {
            activitySection("Savings", count: activity.savingsDeposits.count)

            ForEach(activity.savingsDeposits) { deposit in
                SavingsDepositCard(
                    deposit: deposit,
                    sourceAccountName: deposit.sourceAccountID.flatMap(accountName),
                    withdrawals: savingsWithdrawals,
                    asOf: asOf
                )
            }
        }
    }

    @ViewBuilder
    private func fundsSection(_ activity: BudgetJarActivitySnapshot) -> some View {
        if !activity.fundHoldings.isEmpty {
            activitySection("Funds & gold", count: activity.fundHoldings.count)

            ForEach(activity.fundHoldings) { holding in
                FundHoldingCard(
                    holding: holding,
                    instrument: instrument(for: holding),
                    sales: sales(for: holding),
                    sourceAccountName: holding.sourceAccountID.flatMap(accountName),
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

    private func category(for transaction: MoneyTransaction) -> TransactionCategory? {
        transaction.categoryID.flatMap { id in categories.first { $0.id == id } }
    }

    private func account(_ id: UUID) -> CashAccount? {
        accounts.first { $0.id == id }
    }

    private func accountName(_ id: UUID) -> String? {
        account(id)?.name
    }

    private func tripName(for transaction: MoneyTransaction) -> String? {
        transaction.tripWorkspaceID.flatMap { id in
            tripWorkspaces.first { $0.id == id }?.name
        }
    }

    private func instrument(for holding: FundHolding) -> FundInstrument? {
        holding.instrumentID.flatMap { id in fundInstruments.first { $0.id == id } }
    }

    private func sales(for holding: FundHolding) -> [FundSale] {
        fundSales.filter { $0.holdingID == holding.id }
    }
}
