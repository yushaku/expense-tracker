import SwiftData
import SwiftUI

struct AccountActivityView: View {
    let account: CashAccount

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    header

                    if activity.isEmpty {
                        emptyState
                    } else {
                        ForEach(activity) { item in
                            activityRow(item)
                        }
                    }
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(account.name)
        .accessibilityIdentifier("account-activity")
        .tint(MonMonTheme.accent)
    }

    private var activity: [AccountActivityItem] {
        AccountActivityItem.items(
            for: account.id,
            transactions: transactions,
            transfers: transfers
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("All activity")
                .font(.title3.weight(.semibold))

            Text(activity.count.formatted())
                .font(.caption.weight(.bold))
                .foregroundStyle(MonMonTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MonMonTheme.accent.opacity(0.16), in: Capsule())

            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 56, height: 56)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            Text("No activity recorded for this account.")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityIdentifier("account-activity-empty")
    }

    @ViewBuilder
    private func activityRow(_ item: AccountActivityItem) -> some View {
        switch item {
        case .transaction(let transaction):
            TransactionCard(
                transaction: transaction,
                category: category(for: transaction),
                account: account
            )
            .accessibilityIdentifier("account-activity-transaction-\(transaction.id.uuidString)")

        case .transfer(let transfer):
            TransferCard(
                transfer: transfer,
                sourceAccount: self.account(transfer.sourceAccountID),
                destinationAccount: self.account(transfer.destinationAccountID)
            )
            .accessibilityIdentifier("account-activity-transfer-\(transfer.id.uuidString)")
        }
    }

    private func category(for transaction: MoneyTransaction) -> TransactionCategory? {
        guard let categoryID = transaction.categoryID else {
            return nil
        }

        return categories.first { $0.id == categoryID }
    }

    private func account(_ id: UUID) -> CashAccount? {
        accounts.first { $0.id == id }
    }
}
