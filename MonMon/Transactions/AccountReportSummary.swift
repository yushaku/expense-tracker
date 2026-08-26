import Foundation

struct AccountSpendingRow: Identifiable, Equatable {
    let accountID: UUID
    let amount: Decimal
    let count: Int

    var id: UUID { accountID }
}

enum AccountSpendingSummary {
    /// Expense recorded against each known account in the already-selected
    /// period. Income and transfers never enter this input's totals.
    static func rows(
        accounts: [CashAccount],
        transactions: [MoneyTransaction]
    ) -> [AccountSpendingRow] {
        var totals: [UUID: Decimal] = [:]
        var counts: [UUID: Int] = [:]

        for transaction in transactions where transaction.kind == .expense {
            totals[transaction.accountID, default: .zero] += transaction.amount
            counts[transaction.accountID, default: 0] += 1
        }

        return accounts.enumerated()
            .compactMap { index, account -> (index: Int, row: AccountSpendingRow)? in
                guard let total = totals[account.id] else {
                    return nil
                }

                return (
                    index,
                    AccountSpendingRow(
                        accountID: account.id,
                        amount: total,
                        count: counts[account.id, default: 0]
                    )
                )
            }
            .sorted { left, right in
                if left.row.amount != right.row.amount {
                    return left.row.amount > right.row.amount
                }

                return left.index < right.index
            }
            .map(\.row)
    }
}

enum AccountActivityID: Hashable {
    case transaction(UUID)
    case transfer(UUID)

    fileprivate var sortKey: String {
        switch self {
        case .transaction(let id):
            "transaction-\(id.uuidString)"
        case .transfer(let id):
            "transfer-\(id.uuidString)"
        }
    }
}

enum AccountActivityItem: Identifiable {
    case transaction(MoneyTransaction)
    case transfer(AccountTransfer)

    var id: AccountActivityID {
        switch self {
        case .transaction(let transaction):
            .transaction(transaction.id)
        case .transfer(let transfer):
            .transfer(transfer.id)
        }
    }

    var occurredAt: Date {
        switch self {
        case .transaction(let transaction):
            transaction.occurredAt
        case .transfer(let transfer):
            transfer.occurredAt
        }
    }

    static func items(
        for accountID: UUID,
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer]
    ) -> [AccountActivityItem] {
        let transactionItems =
            transactions
            .filter { $0.accountID == accountID }
            .map(AccountActivityItem.transaction)

        let transferItems =
            transfers
            .filter {
                $0.sourceAccountID == accountID || $0.destinationAccountID == accountID
            }
            .map(AccountActivityItem.transfer)

        return (transactionItems + transferItems).sorted { left, right in
            if left.occurredAt != right.occurredAt {
                return left.occurredAt > right.occurredAt
            }

            return left.id.sortKey < right.id.sortKey
        }
    }
}
