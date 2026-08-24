import SwiftUI

/// The savings half of the Investments screen: what the deposits will pay,
/// followed by a card per savings book. The screen around it owns the scroll,
/// the running total, and the editor sheet.
struct SavingsSection: View {
    let deposits: [SavingsDeposit]
    let accounts: [CashAccount]
    let onAdd: () -> Void
    let onEdit: (SavingsDeposit) -> Void

    var body: some View {
        if deposits.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                detailCard

                depositsSection
            }
        }
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                "Projected interest \(VNDCurrency.format(projectedInterest))",
                systemImage: "chart.line.uptrend.xyaxis"
            )
            .font(.subheadline.weight(.medium))

            Label(depositCountLabel, systemImage: "rectangle.stack.fill")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(MonMonTheme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var projectedInterest: Decimal {
        AssetSummary.totalProjectedInterest(of: deposits)
    }

    private var depositCountLabel: String {
        switch deposits.count {
        case 0:
            "Ready for your first savings book"
        case 1:
            "Across 1 savings book"
        default:
            "Across \(deposits.count) savings books"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.savings)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.savings.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Track your savings books")
                    .font(.title3.weight(.semibold))

                Text(
                    "Add a term deposit to see its maturity date and the interest it will pay."
                )
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            }

            Button("Add Savings Book", systemImage: "plus", action: onAdd)
                .accessibilityIdentifier(InvestmentSegment.savings.addIdentifier)
                .buttonStyle(.prominentAction)
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

    private func accountName(for deposit: SavingsDeposit) -> String? {
        guard let sourceAccountID = deposit.sourceAccountID else {
            return nil
        }

        return accounts.first { $0.id == sourceAccountID }?.name
    }

    private var depositsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Savings books")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(deposits.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.savings)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.savings.opacity(0.16), in: Capsule())
            }

            ForEach(deposits) { deposit in
                Button {
                    onEdit(deposit)
                } label: {
                    SavingsDepositCard(
                        deposit: deposit,
                        sourceAccountName: accountName(for: deposit)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("savings-\(deposit.id.uuidString)")
                .accessibilityHint("Opens this savings book for editing")
            }
        }
    }
}
