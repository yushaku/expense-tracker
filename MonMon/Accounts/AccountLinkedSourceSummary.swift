import Foundation
import SwiftData

enum AccountLinkedSourceKind: CaseIterable, Identifiable {
    case savings
    case funds
    case debts
    case recurring

    var id: Self { self }
}

struct AccountLinkedSourceRow: Equatable, Identifiable {
    let kind: AccountLinkedSourceKind
    let count: Int

    var id: AccountLinkedSourceKind { kind }
}

enum AccountLinkedSourceSummary {
    static func rows(
        for account: CashAccount,
        deposits: [SavingsDeposit],
        withdrawals: [SavingsWithdrawal],
        holdings: [FundHolding],
        sales: [FundSale],
        debts: [Debt],
        payments: [DebtPayment],
        recurringRules: [RecurringRule]
    ) -> [AccountLinkedSourceRow] {
        let counts: [AccountLinkedSourceKind: Int] = [
            .savings: deposits.count { $0.sourceAccountID == account.id }
                + withdrawals.count { $0.destinationAccountID == account.id },
            // A swap paid into no account, so it is not a reason this one
            // cannot be deleted. See `FundSale.swapHoldingID`.
            .funds: holdings.count { $0.sourceAccountID == account.id }
                + sales.count { !$0.isSwap && $0.proceedsAccountID == account.id },
            .debts: debts.count { $0.accountID == account.id }
                + payments.count { $0.accountID == account.id },
            .recurring: recurringRules.count { $0.accountID == account.id },
        ]

        return AccountLinkedSourceKind.allCases.compactMap { kind in
            guard let count = counts[kind], count > 0 else {
                return nil
            }
            return AccountLinkedSourceRow(kind: kind, count: count)
        }
    }
}

/// Moving everything that names one account onto another, so an account can be
/// deleted without leaving records pointing at a row that is no longer there.
///
/// Every account-shaped foreign key in the store is listed in `apply`, and that
/// list is the whole point of this type. `AccountSeed` explains why a dangling
/// one is the single state the app cannot have: a default applies when a field
/// is absent, never when it holds an id that has stopped resolving. A new
/// reference to an account added anywhere else belongs in that list too.
enum AccountMerge {
    /// How many records name this account. Counts the transfers at either end
    /// and the captures still waiting to be reviewed, because both would
    /// outlive the account.
    @MainActor
    static func linkedRecordCount(for account: CashAccount, in context: ModelContext) -> Int {
        apply(from: account, to: nil, in: context)
    }

    /// Repoints every record naming `source` at `destination`, hands over the
    /// opening balance, and deletes the account.
    ///
    /// The balance moves because the records do. Leaving it behind would shrink
    /// the owner's net worth by whatever the account opened with, which is a
    /// deletion of money rather than of an account.
    @MainActor
    static func move(
        from source: CashAccount,
        to destination: CashAccount,
        in context: ModelContext
    ) throws {
        _ = apply(from: source, to: destination, in: context)
        destination.openingBalance += source.openingBalance
        context.delete(source)
        try SyncWriteGate.save(context)
    }

    /// Counts when `destination` is `nil` and rewrites when it is not, so the
    /// figure the confirmation quotes comes from the same walk that does the
    /// work and cannot drift from it.
    @MainActor
    private static func apply(
        from source: CashAccount,
        to destination: CashAccount?,
        in context: ModelContext
    ) -> Int {
        let sourceID = source.id
        var touched = 0

        func fetch<Model: PersistentModel>(_ type: Model.Type) -> [Model] {
            (try? context.fetch(FetchDescriptor<Model>())) ?? []
        }

        func repoint<Model: PersistentModel>(
            _ field: ReferenceWritableKeyPath<Model, UUID>
        ) {
            for record in fetch(Model.self) where record[keyPath: field] == sourceID {
                touched += 1
                if let destination {
                    record[keyPath: field] = destination.id
                }
            }
        }

        func repointOptional<Model: PersistentModel>(
            _ field: ReferenceWritableKeyPath<Model, UUID?>
        ) {
            for record in fetch(Model.self) where record[keyPath: field] == sourceID {
                touched += 1
                if let destination {
                    record[keyPath: field] = destination.id
                }
            }
        }

        repoint(\MoneyTransaction.accountID)
        repoint(\SavingsWithdrawal.destinationAccountID)
        repoint(\FundSale.proceedsAccountID)
        repoint(\DebtPayment.accountID)
        repoint(\RecurringRule.accountID)
        repointOptional(\SavingsDeposit.sourceAccountID)
        repointOptional(\FundHolding.sourceAccountID)
        repointOptional(\Debt.accountID)
        repointOptional(\PendingTransactionCapture.accountID)

        for transfer in fetch(AccountTransfer.self) {
            let leaves = transfer.sourceAccountID == sourceID
            let lands = transfer.destinationAccountID == sourceID
            guard leaves || lands else {
                continue
            }

            touched += 1

            guard let destination else {
                continue
            }

            // A transfer whose other end is the destination would name the same
            // account twice, and money moved to where it already is moves
            // nothing. It goes, rather than staying as a row saying nothing
            // happened — the balances agree either way, since what it took off
            // one end it put back on the other.
            let otherEnd = leaves ? transfer.destinationAccountID : transfer.sourceAccountID
            guard otherEnd != destination.id else {
                context.delete(transfer)
                continue
            }

            if leaves {
                transfer.sourceAccountID = destination.id
            } else {
                transfer.destinationAccountID = destination.id
            }
        }

        return touched
    }
}

/// Linked investments are unique parent positions, whether this account funded
/// them or received their cash proceeds. Swaps never link a cash account.
enum AccountLinkedInvestments {
    static func deposits(
        for accountID: UUID, deposits: [SavingsDeposit], withdrawals: [SavingsWithdrawal]
    ) -> [SavingsDeposit] {
        let receivedIDs = Set(
            withdrawals.filter { $0.destinationAccountID == accountID }.compactMap(\.depositID))
        return deposits.filter { $0.sourceAccountID == accountID || receivedIDs.contains($0.id) }
    }

    static func holdings(
        for accountID: UUID, holdings: [FundHolding], sales: [FundSale]
    ) -> [FundHolding] {
        let receivedIDs = Set(
            sales.filter { !$0.isSwap && $0.proceedsAccountID == accountID }.compactMap(\.holdingID)
        )
        return holdings.filter { $0.sourceAccountID == accountID || receivedIDs.contains($0.id) }
    }
}
