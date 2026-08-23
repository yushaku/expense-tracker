import Foundation

enum TransferSummary {
    static func total(of transfers: [AccountTransfer]) -> Decimal {
        transfers.reduce(Decimal.zero) { total, transfer in
            total + transfer.amount
        }
    }

    /// Money transferred into this account minus money transferred out of it,
    /// over all time. Summed across every account this is always zero: an
    /// internal transfer moves money, it does not create or destroy any.
    static func netFlow(for account: CashAccount, transfers: [AccountTransfer]) -> Decimal {
        transfers.reduce(Decimal.zero) { total, transfer in
            total + transfer.signedAmount(for: account.id)
        }
    }

    /// Every transfer that touches this account, on either end.
    static func count(for account: CashAccount, transfers: [AccountTransfer]) -> Int {
        transfers.filter {
            $0.sourceAccountID == account.id || $0.destinationAccountID == account.id
        }
        .count
    }

    static func inRange(
        _ range: TransactionRange,
        transfers: [AccountTransfer]
    ) -> [AccountTransfer] {
        transfers.filter { range.contains($0.occurredAt) }
    }
}
