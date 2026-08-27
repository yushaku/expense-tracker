import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Debt payment persistence")
@MainActor
struct DebtPaymentPersistenceTests {
    private let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)

    /// Returns the container, not just its context: a `ModelContext` does not
    /// keep its container alive, and a released container leaves the context
    /// dangling, which traps inside SwiftData on the next insert.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: CashAccount.self, MoneyTransaction.self, TransactionCategory.self,
            SavingsDeposit.self, FundHolding.self, AccountTransfer.self,
            Debt.self, DebtPayment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeAccount(
        name: String,
        kind: CashAccountKind = .normal,
        openingBalance: Decimal
    ) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: name,
            kind: kind,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
    }

    private func makeDebt(
        direction: DebtDirection = .borrowed,
        principal: Decimal,
        accountID: UUID?
    ) -> Debt {
        Debt(
            id: UUID(),
            counterparty: "Anh Minh",
            direction: direction,
            principal: principal,
            annualInterestRate: 0,
            openedAt: occurredAt,
            dueDate: nil,
            accountID: accountID,
            note: "",
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
    }

    private func makePayment(
        _ amount: Decimal,
        debtID: UUID,
        accountID: UUID,
        note: String = ""
    ) -> DebtPayment {
        DebtPayment(
            id: UUID(),
            debtID: debtID,
            amount: amount,
            occurredAt: occurredAt,
            accountID: accountID,
            note: note,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
    }

    private func available(
        _ account: CashAccount,
        in context: ModelContext
    ) throws -> Decimal {
        CashBalanceSummary.available(
            for: account,
            deposits: [],
            holdings: [],
            withdrawals: [],
            transactions: try context.fetch(FetchDescriptor<MoneyTransaction>()),
            transfers: [],
            debts: try context.fetch(FetchDescriptor<Debt>()),
            payments: try context.fetch(FetchDescriptor<DebtPayment>()),
            sales: []
        )
    }

    private func outstanding(_ debt: Debt, in context: ModelContext) throws -> Decimal {
        DebtSummary.outstanding(
            for: debt,
            payments: try context.fetch(FetchDescriptor<DebtPayment>())
        )
    }

    // MARK: - Round trip

    @Test("A payment round trips through the store")
    func paymentRoundTrips() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 50_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: account.id)
        let payment = makePayment(
            5_000_000,
            debtID: debt.id,
            accountID: account.id,
            note: "March"
        )

        context.insert(account)
        context.insert(debt)
        context.insert(payment)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<DebtPayment>()).first)

        #expect(stored.debtID == debt.id)
        #expect(stored.amount == 5_000_000)
        #expect(stored.accountID == account.id)
        #expect(stored.note == "March")
        #expect(stored.occurredAt == occurredAt)
        #expect(stored.currencyCode == VNDCurrency.code)
    }

    // MARK: - Balances

    @Test("A stored payment on a borrowed debt lowers the account it left")
    func repayingLowersTheAccount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: account.id)
        let payment = makePayment(5_000_000, debtID: debt.id, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        context.insert(payment)
        try context.save()

        // 10m opening + 30m borrowed − 5m repaid.
        #expect(try available(account, in: context) == 35_000_000)
        #expect(try outstanding(debt, in: context) == 25_000_000)
    }

    @Test("A stored payment on a lent debt raises the account it reached")
    func beingRepaidRaisesTheAccount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(direction: .lent, principal: 4_000_000, accountID: account.id)
        let payment = makePayment(1_000_000, debtID: debt.id, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        context.insert(payment)
        try context.save()

        // 10m opening − 4m lent + 1m returned.
        #expect(try available(account, in: context) == 7_000_000)
        #expect(try outstanding(debt, in: context) == 3_000_000)
    }

    @Test("A payment may leave an account other than the one that opened the debt")
    func payingFromAnotherAccount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let wallet = makeAccount(name: "Wallet", openingBalance: 0)
        let bank = makeAccount(name: "Bank", openingBalance: 20_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: wallet.id)
        let payment = makePayment(5_000_000, debtID: debt.id, accountID: bank.id)

        context.insert(wallet)
        context.insert(bank)
        context.insert(debt)
        context.insert(payment)
        try context.save()

        #expect(try available(wallet, in: context) == 30_000_000)
        #expect(try available(bank, in: context) == 15_000_000)
    }

    @Test("Deleting a payment restores both the account balance and the outstanding figure")
    func deletingAPaymentRestoresBoth() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: account.id)
        let payment = makePayment(5_000_000, debtID: debt.id, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        context.insert(payment)
        try context.save()

        context.delete(payment)
        try context.save()

        #expect(try available(account, in: context) == 40_000_000)
        #expect(try outstanding(debt, in: context) == 30_000_000)
    }

    @Test("Several payments settle a debt exactly")
    func severalPaymentsSettleExactly() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        for amount in [10_000_000, 15_000_000, 5_000_000] as [Decimal] {
            context.insert(makePayment(amount, debtID: debt.id, accountID: account.id))
        }
        try context.save()

        let payments = try context.fetch(FetchDescriptor<DebtPayment>())

        #expect(try outstanding(debt, in: context) == 0)
        #expect(DebtSummary.isSettled(debt, payments: payments))
        // Back where it started: the borrowed money came and went.
        #expect(try available(account, in: context) == 10_000_000)
    }

    @Test("Editing a payment down frees the difference to be paid again")
    func editingAPaymentDownFreesTheDifference() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: account.id)
        let payment = makePayment(30_000_000, debtID: debt.id, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        context.insert(payment)
        try context.save()

        #expect(try outstanding(debt, in: context) == 0)

        payment.amount = 20_000_000
        try context.save()

        #expect(try outstanding(debt, in: context) == 10_000_000)
        #expect(try available(account, in: context) == 20_000_000)
    }

    // MARK: - Boundaries

    @Test("A payment is not income or expense, so the Spending totals ignore it")
    func paymentsStayOutOfSpending() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        context.insert(makePayment(5_000_000, debtID: debt.id, accountID: account.id))
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())

        #expect(transactions.isEmpty)
        #expect(TransactionSummary.totalExpense(of: transactions) == 0)
    }

    @Test("An account named only by a payment still reports it against deletion")
    func anAccountNamedOnlyByAPaymentIsBlocked() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let wallet = makeAccount(name: "Wallet", openingBalance: 0)
        let bank = makeAccount(name: "Bank", openingBalance: 5_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: wallet.id)

        context.insert(wallet)
        context.insert(bank)
        context.insert(debt)
        context.insert(makePayment(5_000_000, debtID: debt.id, accountID: bank.id))
        try context.save()

        let debts = try context.fetch(FetchDescriptor<Debt>())
        let payments = try context.fetch(FetchDescriptor<DebtPayment>())

        // The bank names no debt, only a payment, and it nets to zero.
        #expect(try available(bank, in: context) == 0)
        #expect(DebtSummary.count(for: bank, debts: debts, payments: payments) == 1)
    }
}
