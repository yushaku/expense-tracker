import Foundation

enum CashBalanceSummary {
    static func total(of accounts: [CashAccount]) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            total + account.openingBalance
        }
    }
}
