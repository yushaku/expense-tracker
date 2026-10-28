import SwiftUI

/// One account's card. The balance is handed in, worked out by the screen with
/// `CashBalanceSummary.balances` in one pass for every card it shows, rather
/// than each card rescanning the whole ledger (several times, since
/// `ViewThatFits` builds both layouts).
struct CashAccountCard: View {
    let account: CashAccount
    let availableBalance: Decimal
    let deposits: [SavingsDeposit]
    let withdrawals: [SavingsWithdrawal]
    let holdings: [FundHolding]
    let sales: [FundSale]

    var body: some View {
        let figures = Figures(
            available: availableBalance,
            credit: CashBalanceSummary.availableCredit(
                limit: account.creditLimit,
                currentBalance: availableBalance
            ),
            savings: savingsAmount,
            funds: fundsAmount
        )

        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                identity
                Spacer(minLength: 12)
                balance(figures, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 16) {
                identity
                balance(figures, alignment: .leading)
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
                .foregroundStyle(account.tint)
                .frame(width: 44, height: 44)
                .background(account.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))
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

    /// Everything the balance column shows, worked out once per body and
    /// shared by both of `ViewThatFits`'s layouts.
    private struct Figures {
        let available: Decimal
        let credit: Decimal
        let savings: Decimal
        let funds: Decimal
    }

    private func balance(_ figures: Figures, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(VNDCurrency.format(figures.available))
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(
                    figures.available < 0 ? MonMonTheme.danger : MonMonTheme.textPrimary
                )

            Text(account.kind == .credit ? "CURRENT BALANCE" : "AVAILABLE BALANCE")
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(MonMonTheme.textSecondary)

            if account.kind == .credit {
                Text(VNDCurrency.format(figures.credit))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(MonMonTheme.credit)
                    .padding(.top, 5)

                Text("AVAILABLE CREDIT")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            if figures.savings > 0 {
                Text("In savings \(VNDCurrency.format(figures.savings))")
                    .font(.caption)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(MonMonTheme.savings)
            }

            if figures.funds > 0 {
                Text("In funds \(VNDCurrency.format(figures.funds))")
                    .font(.caption)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(MonMonTheme.funds)
            }
        }
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
                    account: .preview(name: "Wallet", kind: .normal, openingBalance: 1_250_000),
                    availableBalance: 1_250_000,
                    deposits: [],
                    withdrawals: [],
                    holdings: [],
                    sales: []
                )

                CashAccountCard(
                    account: .preview(
                        name: "Techcombank",
                        kind: .normal,
                        openingBalance: 48_900_000
                    ),
                    availableBalance: 48_900_000,
                    deposits: [],
                    withdrawals: [],
                    holdings: [],
                    sales: []
                )

                CashAccountCard(
                    account: .preview(
                        name: "Visa credit",
                        kind: .credit,
                        openingBalance: -5_200_000,
                        creditLimit: 20_000_000
                    ),
                    availableBalance: -5_200_000,
                    deposits: [],
                    withdrawals: [],
                    holdings: [],
                    sales: []
                )

                CashAccountCard(
                    account: .preview(
                        name: "Very long account name that wraps to two lines",
                        kind: .normal,
                        openingBalance: 987_654_321_000
                    ),
                    availableBalance: 987_654_321_000,
                    deposits: [],
                    withdrawals: [],
                    holdings: [],
                    sales: []
                )
            }
            .padding(20)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
