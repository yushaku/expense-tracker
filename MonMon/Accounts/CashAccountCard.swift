import SwiftUI

struct CashAccountCard: View {
    let account: CashAccount
    let deposits: [SavingsDeposit]
    let withdrawals: [SavingsWithdrawal]
    let holdings: [FundHolding]
    let transactions: [MoneyTransaction]
    let transfers: [AccountTransfer]
    let debts: [Debt]
    let payments: [DebtPayment]
    let sales: [FundSale]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                identity
                Spacer(minLength: 12)
                balance(alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 16) {
                identity
                balance(alignment: .leading)
            }
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

    private var identity: some View {
        HStack(spacing: 14) {
            Image(systemName: account.kind.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(account.kind.tint)
                .frame(width: 44, height: 44)
                .background(account.kind.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(account.kind.displayName)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private func balance(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(VNDCurrency.format(availableBalance))
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(
                    availableBalance < 0 ? MonMonTheme.danger : MonMonTheme.textPrimary
                )

            Text(account.kind == .credit ? "CURRENT BALANCE" : "AVAILABLE BALANCE")
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(MonMonTheme.textSecondary)

            if savingsAmount > 0 {
                Text("In savings \(VNDCurrency.format(savingsAmount))")
                    .font(.caption)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(MonMonTheme.savings)
            }

            if fundsAmount > 0 {
                Text("In funds \(VNDCurrency.format(fundsAmount))")
                    .font(.caption)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(MonMonTheme.funds)
            }
        }
    }

    private var availableBalance: Decimal {
        CashBalanceSummary.available(
            for: account,
            deposits: deposits,
            holdings: holdings,
            withdrawals: withdrawals,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments,
            sales: sales
        )
    }

    private var savingsAmount: Decimal {
        deposits.reduce(Decimal.zero) { total, deposit in
            deposit.sourceAccountID == account.id
                ? total + deposit.remainingPrincipal(withdrawals: withdrawals) : total
        }
    }

    /// What this account put into funds and gold that is still there.
    ///
    /// Counts the cost of the units still held rather than everything ever
    /// bought: once a position is sold the money is no longer parked, it is back
    /// in an account and already counted in the available balance above. Saying
    /// otherwise would show the same đồng twice on one card.
    private var fundsAmount: Decimal {
        holdings.reduce(Decimal.zero) { total, holding in
            holding.sourceAccountID == account.id
                ? total + holding.remainingCostBasis(sales: sales) : total
        }
    }
}

#if DEBUG
    #Preview("Cards") {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 16) {
                CashAccountCard(
                    account: .preview(name: "Wallet", kind: .cash, openingBalance: 1_250_000),
                    deposits: [],
                    withdrawals: [],
                    holdings: [],
                    transactions: [],
                    transfers: [],
                    debts: [],
                    payments: [],
                    sales: []
                )

                CashAccountCard(
                    account: .preview(name: "Techcombank", kind: .bank, openingBalance: 48_900_000),
                    deposits: [],
                    withdrawals: [],
                    holdings: [],
                    transactions: [],
                    transfers: [],
                    debts: [],
                    payments: [],
                    sales: []
                )

                CashAccountCard(
                    account: .preview(
                        name: "Visa credit",
                        kind: .credit,
                        openingBalance: -5_200_000
                    ),
                    deposits: [],
                    withdrawals: [],
                    holdings: [],
                    transactions: [],
                    transfers: [],
                    debts: [],
                    payments: [],
                    sales: []
                )

                CashAccountCard(
                    account: .preview(
                        name: "Very long account name that wraps to two lines",
                        kind: .bank,
                        openingBalance: 987_654_321_000
                    ),
                    deposits: [],
                    withdrawals: [],
                    holdings: [],
                    transactions: [],
                    transfers: [],
                    debts: [],
                    payments: [],
                    sales: []
                )
            }
            .padding(20)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
