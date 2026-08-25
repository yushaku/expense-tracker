import SwiftUI

struct SavingsDepositCard: View {
    @Environment(\.locale) private var locale

    let deposit: SavingsDeposit
    let sourceAccountName: String?
    let withdrawals: [SavingsWithdrawal]
    var asOf: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
                .overlay(MonMonTheme.border)
            terms
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .opacity(status == .settled ? 0.68 : 1)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "banknote.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MonMonTheme.savings)
                .frame(width: 44, height: 44)
                .background(
                    MonMonTheme.savings.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(deposit.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(statusTitle)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.14), in: Capsule())

                // A book funded from an account says which one. One that names
                // no account says nothing: "no linked account" filled the line
                // with the absence of a fact rather than with a fact.
                if let sourceAccountName {
                    Text("Funded from \(sourceAccountName)")
                        .font(.subheadline)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(VNDCurrency.format(deposit.remainingPrincipal(withdrawals: withdrawals)))
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("REMAINING")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    /// One term to a line, label left and figure right. Five of these side by
    /// side left an iPhone shrinking every figure to fit; stacked, each one
    /// keeps its own line and the amounts line up down the right edge.
    private var terms: some View {
        VStack(alignment: .leading, spacing: 10) {
            detail(
                title: "RATE",
                value: PercentInput.formatWithSymbol(deposit.annualInterestRate)
            )
            detail(title: "TERM", value: termDescription)
            detail(title: "MATURES", value: maturityDescription)
            detail(
                title: "INTEREST",
                value: VNDCurrency.format(deposit.projectedInterest(withdrawals: withdrawals))
            )
            detail(
                title: "AT MATURITY",
                value: VNDCurrency.format(deposit.maturityValue(withdrawals: withdrawals))
            )
        }
    }

    private func detail(title: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(MonMonTheme.textSecondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.trailing)
        }
    }

    private var termDescription: String {
        AppText.string("\(deposit.termMonths) months", in: locale)
    }

    private var maturityDescription: String {
        TransactionPeriod.day(deposit.maturityDate, in: locale)
    }

    private var status: SavingsDepositStatus {
        deposit.status(withdrawals: withdrawals, asOf: asOf)
    }

    private var statusTitle: LocalizedStringKey {
        switch status {
        case .active:
            "ACTIVE"
        case .matured:
            "MATURED"
        case .settled:
            "SETTLED"
        }
    }

    private var statusColor: Color {
        switch status {
        case .active:
            MonMonTheme.savings
        case .matured:
            MonMonTheme.accent
        case .settled:
            MonMonTheme.textSecondary
        }
    }
}

#if DEBUG
    #Preview("Deposit cards") {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 16) {
                SavingsDepositCard(
                    deposit: .preview(
                        name: "Techcombank 6 tháng",
                        principal: 100_000_000,
                        annualInterestRate: Decimal(string: "5.6") ?? 0,
                        termMonths: 6
                    ),
                    sourceAccountName: "Techcombank",
                    withdrawals: []
                )

                SavingsDepositCard(
                    deposit: .preview(
                        name: "A very long savings book name that wraps",
                        principal: 9_876_543_210,
                        annualInterestRate: Decimal(string: "6.15") ?? 0,
                        termMonths: 24
                    ),
                    sourceAccountName: nil,
                    withdrawals: []
                )
            }
            .padding(20)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
