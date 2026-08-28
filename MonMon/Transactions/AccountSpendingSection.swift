import SwiftUI

struct AccountSpendingSection: View {
    @Environment(\.locale) private var locale

    let monthTitle: String
    let rows: [AccountSpendingRow]
    let accounts: [CashAccount]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if displayRows.isEmpty {
                emptyState
            } else {
                AllocationDoughnut(
                    context: monthTitle,
                    items: doughnutItems,
                    totalLabel: TransactionKind.expense.displayName(in: locale),
                    showsLegend: false
                )

                Divider()
                    .overlay(MonMonTheme.border)

                accountRows
            }
        }
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
        .accessibilityIdentifier("report-account-spending")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label("BY ACCOUNT", systemImage: "chart.pie.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

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
        Text("No spending recorded this month.")
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .accessibilityIdentifier("report-account-spending-empty")
    }

    private var accountRows: some View {
        VStack(spacing: 10) {
            ForEach(displayRows) { row in
                NavigationLink(value: AccountDetailRoute(accountID: row.account.id)) {
                    accountRow(row)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    "report-account-spending-\(row.account.id.uuidString)"
                )
                .accessibilityHint("Shows account details and activity.")
            }
        }
    }

    private func accountRow(_ row: AccountSpendingDisplayRow) -> some View {
        HStack(spacing: 14) {
            Image(systemName: row.account.kind.iconName)
                .font(.footnote.weight(.bold))
                .foregroundStyle(row.tint)
                .frame(width: 34, height: 34)
                .background(row.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.account.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(countLabel(row.summary))
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(VNDCurrency.format(row.summary.amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(Percentage.label(of: row.summary.amount, in: total))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MonMonTheme.textMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            """
            \(row.account.name), \(VNDCurrency.format(row.summary.amount)), \
            \(Percentage.label(of: row.summary.amount, in: total)), \
            \(countLabel(row.summary))
            """
        )
    }

    private var total: Decimal {
        rows.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var displayRows: [AccountSpendingDisplayRow] {
        rows.compactMap { summary in
            guard let accountIndex = accounts.firstIndex(where: { $0.id == summary.accountID })
            else {
                return nil
            }

            return AccountSpendingDisplayRow(
                account: accounts[accountIndex],
                summary: summary,
                tint: AccountPalette.tint(at: accountIndex)
            )
        }
    }

    private var doughnutItems: [AllocationDoughnutItem] {
        displayRows.map { row in
            AllocationDoughnutItem(
                id: row.account.id.uuidString,
                name: row.account.name,
                amount: row.summary.amount,
                tint: row.tint,
                symbolName: row.account.kind.iconName
            )
        }
    }

    private func countLabel(_ row: AccountSpendingRow) -> String {
        AppText.string("\(row.count) transactions", in: locale)
    }
}

private struct AccountSpendingDisplayRow: Identifiable {
    let account: CashAccount
    let summary: AccountSpendingRow
    let tint: Color

    var id: UUID { account.id }
}
