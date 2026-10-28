import Foundation
import SwiftData

/// `CashBalanceSummary.available` for one account, from fetches cut to the
/// rows that can move it.
///
/// The editors that guard against an overdraft used to hold `@Query`s over
/// every transaction, transfer and debt payment in the store just to work out
/// one account's balance, and recomputed it on every keystroke. Every record
/// that does not name the account contributes zero to `available`, so leaving
/// those rows out of the fetch gives the same figure. Debts are fetched whole:
/// a payment from this account takes its direction from its debt, which may
/// have been opened against another account.
///
/// A failed fetch counts as no rows, the way an empty `@Query` would have.
enum CashBalanceFetch {
    @MainActor
    static func available(for account: CashAccount, in context: ModelContext) -> Decimal {
        let id = account.id
        let optionalID: UUID? = id

        func fetch<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) -> [Model] {
            (try? context.fetch(descriptor)) ?? []
        }

        return CashBalanceSummary.available(
            for: account,
            deposits: fetch(
                FetchDescriptor<SavingsDeposit>(
                    predicate: #Predicate { $0.sourceAccountID == optionalID })),
            holdings: fetch(
                FetchDescriptor<FundHolding>(
                    predicate: #Predicate { $0.sourceAccountID == optionalID })),
            withdrawals: fetch(
                FetchDescriptor<SavingsWithdrawal>(
                    predicate: #Predicate { $0.destinationAccountID == id })),
            transactions: fetch(LedgerFetch.transactions(inAccount: id)),
            transfers: fetch(LedgerFetch.transfers(touching: id)),
            debts: fetch(FetchDescriptor<Debt>()),
            payments: fetch(
                FetchDescriptor<DebtPayment>(predicate: #Predicate { $0.accountID == id })),
            sales: fetch(
                FetchDescriptor<FundSale>(predicate: #Predicate { $0.proceedsAccountID == id }))
        )
    }
}
