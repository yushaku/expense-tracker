import SwiftUI

struct AccountActivityRoute: Hashable {
    let accountID: UUID
}

struct AccountSpendingSection: View {
    let monthTitle: String
    let rows: [AccountSpendingRow]
    let accounts: [CashAccount]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            VStack(spacing: 0) {
                if rows.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if let account = account(row.accountID) {
                            NavigationLink(value: AccountActivityRoute(accountID: account.id)) {
                                accountRow(account, spending: row.amount)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(
                                "report-account-spending-\(account.id.uuidString)"
                            )
                            .accessibilityHint("Shows all activity for this account.")

                            if index < rows.count - 1 {
                                Divider()
                                    .overlay(MonMonTheme.border)
                                    .padding(.leading, 68)
                            }
                        }
                    }
                }
            }
            .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
        }
        .accessibilityIdentifier("report-account-spending")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Spending by account")
                .font(.title3.weight(.semibold))

            Spacer(minLength: 8)

            Text(monthTitle.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "wallet.bifold")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.textMuted)
                .accessibilityHidden(true)

            Text("No spending recorded this month.")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)

            Spacer(minLength: 0)
        }
        .padding(16)
        .accessibilityIdentifier("report-account-spending-empty")
    }

    private func accountRow(_ account: CashAccount, spending: Decimal) -> some View {
        HStack(spacing: 12) {
            Image(systemName: account.kind.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(account.kind.tint)
                .frame(width: 40, height: 40)
                .background(account.kind.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textPrimary)
                    .lineLimit(1)

                Text(account.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(VNDCurrency.format(spending))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(MonMonTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MonMonTheme.textMuted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func account(_ id: UUID) -> CashAccount? {
        accounts.first { $0.id == id }
    }
}
