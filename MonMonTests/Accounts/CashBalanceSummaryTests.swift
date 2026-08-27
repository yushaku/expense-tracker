import Foundation
import Testing

@testable import MonMon

@Suite("Cash balance summary")
@MainActor
struct CashBalanceSummaryTests {
    @Test("Available Credit subtracts debt from the card limit")
    func availableCreditSubtractsDebt() {
        #expect(
            CashBalanceSummary.availableCredit(
                limit: 20_000_000,
                currentBalance: -5_200_000
            ) == 14_800_000
        )
    }

    @Test("Available Credit never reports a negative amount")
    func availableCreditStopsAtZero() {
        #expect(
            CashBalanceSummary.availableCredit(
                limit: 20_000_000,
                currentBalance: -25_000_000
            ) == 0
        )
    }

    @Test("A positive card balance increases Available Credit")
    func overpaymentIncreasesAvailableCredit() {
        #expect(
            CashBalanceSummary.availableCredit(
                limit: 20_000_000,
                currentBalance: 1_000_000
            ) == 21_000_000
        )
    }

    @Test("An empty account list has a zero total")
    func emptyListHasZeroTotal() {
        #expect(CashBalanceSummary.total(of: []) == 0)
    }

    @Test("One account contributes its exact opening balance")
    func oneAccountHasItsOpeningBalance() {
        let account = makeAccount(kind: .normal, openingBalance: Decimal(1_250_000))

        #expect(CashBalanceSummary.total(of: [account]) == Decimal(1_250_000))
    }

    @Test("Cash and bank balances add without floating-point conversion")
    func multipleAccountBalancesAddExactly() {
        let cash = makeAccount(kind: .normal, openingBalance: Decimal(1_250_000))
        let bank = makeAccount(kind: .normal, openingBalance: Decimal(8_750_000))

        #expect(CashBalanceSummary.total(of: [cash, bank]) == Decimal(10_000_000))
    }

    @Test("Recorded income raises the available balance and expense lowers it")
    func flowMovesAvailableBalance() {
        let account = makeUniqueAccount(openingBalance: 10_000_000)
        let transactions = [
            makeTransaction(kind: .expense, amount: 200_000, accountID: account.id),
            makeTransaction(kind: .income, amount: 5_000_000, accountID: account.id),
        ]

        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: [],
                withdrawals: [],
                transactions: transactions,
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == 14_800_000
        )
    }

    @Test("Another account's transactions leave this balance alone")
    func flowIsScopedToOneAccount() {
        let wallet = makeUniqueAccount(openingBalance: 1_000_000)
        let bank = makeUniqueAccount(openingBalance: 9_000_000)
        let transactions = [
            makeTransaction(kind: .expense, amount: 400_000, accountID: bank.id)
        ]

        #expect(
            CashBalanceSummary.available(
                for: wallet,
                deposits: [],
                holdings: [],
                withdrawals: [],
                transactions: transactions,
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == 1_000_000
        )
        #expect(
            CashBalanceSummary.totalAvailable(
                of: [wallet, bank],
                deposits: [],
                holdings: [],
                withdrawals: [],
                transactions: transactions,
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == 9_600_000
        )
    }

    @Test("Spending past the balance is allowed and reports a negative figure")
    func flowMayDriveTheBalanceNegative() {
        let account = makeUniqueAccount(openingBalance: 100_000)
        let transactions = [
            makeTransaction(kind: .expense, amount: 350_000, accountID: account.id)
        ]

        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: [],
                withdrawals: [],
                transactions: transactions,
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == -250_000
        )
    }

    @Test("Flow, a deposit, and a holding each take their đồng exactly once")
    func flowCombinesWithFundedAmounts() {
        let account = makeUniqueAccount(openingBalance: 50_000_000)
        let deposit = SavingsDeposit(
            id: UUID(),
            name: "Techcombank",
            principal: 20_000_000,
            annualInterestRate: 5,
            termMonths: 6,
            openedAt: fixedDate,
            currencyCode: VNDCurrency.code,
            createdAt: fixedDate,
            sourceAccountID: account.id
        )
        let instrument = FundTestFactory.instrument(pricePerUnit: 50_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 100,
            averageCostPerUnit: 50_000,
            sourceAccountID: account.id
        )
        let transactions = [
            makeTransaction(kind: .expense, amount: 1_000_000, accountID: account.id)
        ]

        // 50.000.000 − 1.000.000 spent − 20.000.000 deposited − 5.000.000 invested
        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [deposit],
                holdings: [holding],
                withdrawals: [],
                transactions: transactions,
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == 24_000_000
        )
    }

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeUniqueAccount(openingBalance: Decimal) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: "Account",
            kind: .normal,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: fixedDate
        )
    }

    private func makeTransaction(
        kind: TransactionKind,
        amount: Decimal,
        accountID: UUID
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: kind,
            amount: amount,
            occurredAt: fixedDate,
            note: "",
            accountID: accountID,
            categoryID: nil,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: fixedDate
        )
    }

    private func makeAccount(
        kind: CashAccountKind,
        openingBalance: Decimal
    ) -> CashAccount {
        CashAccount(
            id: UUID(
                uuid: (
                    0x8B, 0x9F, 0x38, 0x8D, 0x0D, 0xF7, 0x4C, 0x70,
                    0xA2, 0x69, 0x00, 0xC3, 0xF6, 0xA7, 0x54, 0xAF
                )
            ),
            name: "Account",
            kind: kind,
            openingBalance: openingBalance,
            currencyCode: "VND",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
