import Foundation
import Testing

@testable import MonMon

@Suite("Transaction summary")
struct TransactionSummaryTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return TransactionPeriod.calendar.date(from: components) ?? .distantPast
    }

    private func makeAccount(openingBalance: Decimal = 0) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: "Wallet",
            kind: .cash,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    private func makeTransaction(
        kind: TransactionKind,
        amount: Decimal,
        accountID: UUID,
        occurredAt: Date? = nil,
        categoryID: UUID? = nil
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: kind,
            amount: amount,
            occurredAt: occurredAt ?? createdAt,
            note: "",
            accountID: accountID,
            categoryID: categoryID,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    @Test("No transactions total to zero")
    func emptyTotalsAreZero() {
        #expect(TransactionSummary.totalIncome(of: []) == 0)
        #expect(TransactionSummary.totalExpense(of: []) == 0)
        #expect(TransactionSummary.net(of: []) == 0)
    }

    @Test("Income and expense are totalled separately and netted")
    func totalsSplitByKind() {
        let account = makeAccount()
        let transactions = [
            makeTransaction(kind: .income, amount: 5_000_000, accountID: account.id),
            makeTransaction(kind: .expense, amount: 200_000, accountID: account.id),
            makeTransaction(kind: .expense, amount: 300_000, accountID: account.id),
        ]

        #expect(TransactionSummary.totalIncome(of: transactions) == 5_000_000)
        #expect(TransactionSummary.totalExpense(of: transactions) == 500_000)
        #expect(TransactionSummary.net(of: transactions) == 4_500_000)
    }

    @Test("Net flow counts only the transactions of one account")
    func netFlowIsPerAccount() {
        let wallet = makeAccount()
        let bank = makeAccount()
        let transactions = [
            makeTransaction(kind: .income, amount: 1_000_000, accountID: wallet.id),
            makeTransaction(kind: .expense, amount: 400_000, accountID: wallet.id),
            makeTransaction(kind: .expense, amount: 900_000, accountID: bank.id),
        ]

        #expect(TransactionSummary.netFlow(for: wallet, transactions: transactions) == 600_000)
        #expect(TransactionSummary.netFlow(for: bank, transactions: transactions) == -900_000)
    }

    @Test("An account with no transactions has no flow")
    func untouchedAccountHasNoFlow() {
        let wallet = makeAccount()
        let bank = makeAccount()
        let transactions = [
            makeTransaction(kind: .income, amount: 1_000_000, accountID: wallet.id)
        ]

        #expect(TransactionSummary.netFlow(for: bank, transactions: transactions) == 0)
        #expect(TransactionSummary.count(for: bank, transactions: transactions) == 0)
        #expect(TransactionSummary.count(for: wallet, transactions: transactions) == 1)
    }

    @Test("Filtering by month keeps only that month's transactions")
    func monthFilterSelectsOneMonth() {
        let account = makeAccount()
        let transactions = [
            makeTransaction(
                kind: .expense,
                amount: 100_000,
                accountID: account.id,
                occurredAt: date(2026, 7, 31)
            ),
            makeTransaction(
                kind: .expense,
                amount: 200_000,
                accountID: account.id,
                occurredAt: date(2026, 8, 1)
            ),
            makeTransaction(
                kind: .income,
                amount: 900_000,
                accountID: account.id,
                occurredAt: date(2026, 8, 31)
            ),
            makeTransaction(
                kind: .expense,
                amount: 300_000,
                accountID: account.id,
                occurredAt: date(2026, 9, 1)
            ),
        ]

        let august = TransactionSummary.inRange(
            .month(containing: date(2026, 8, 15)),
            transactions: transactions
        )

        #expect(august.count == 2)
        #expect(TransactionSummary.net(of: august) == 700_000)
    }

    @Test("Category use is counted by identifier")
    func categoryUseIsCounted() {
        let account = makeAccount()
        let food = TransactionCategory(
            id: UUID(),
            name: "Food",
            kind: .expense,
            symbolName: CategoryPalette.defaultSymbolName,
            colorName: CategoryPalette.defaultColorName,
            createdAt: createdAt
        )
        let transactions = [
            makeTransaction(
                kind: .expense,
                amount: 100_000,
                accountID: account.id,
                categoryID: food.id
            ),
            makeTransaction(kind: .expense, amount: 200_000, accountID: account.id),
        ]

        #expect(TransactionSummary.count(for: food, transactions: transactions) == 1)
    }
}
