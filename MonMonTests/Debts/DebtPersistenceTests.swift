import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Debt persistence")
@MainActor
struct DebtPersistenceTests {
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
        kind: CashAccountKind = .bank,
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
        rate: Decimal = 0,
        dueDate: Date? = nil,
        accountID: UUID?
    ) -> Debt {
        Debt(
            id: UUID(),
            counterparty: "Anh Minh",
            direction: direction,
            principal: principal,
            annualInterestRate: rate,
            openedAt: occurredAt,
            dueDate: dueDate,
            accountID: accountID,
            note: "a loan",
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
    }

    private func makePayment(
        _ amount: Decimal,
        debtID: UUID,
        accountID: UUID
    ) -> DebtPayment {
        DebtPayment(
            id: UUID(),
            debtID: debtID,
            amount: amount,
            occurredAt: occurredAt,
            accountID: accountID,
            note: "",
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

    // MARK: - Round trips

    @Test("A borrowed debt round trips through the store")
    func borrowedDebtRoundTrips() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 0)
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let debt = makeDebt(
            principal: 30_000_000,
            rate: Decimal(string: "8.5") ?? 0,
            dueDate: dueDate,
            accountID: account.id
        )

        context.insert(account)
        context.insert(debt)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<Debt>()).first)

        #expect(stored.counterparty == "Anh Minh")
        #expect(stored.direction == .borrowed)
        #expect(stored.principal == 30_000_000)
        #expect(stored.annualInterestRate == Decimal(string: "8.5"))
        #expect(stored.dueDate == dueDate)
        #expect(stored.accountID == account.id)
        #expect(stored.note == "a loan")
        #expect(stored.currencyCode == VNDCurrency.code)
    }

    @Test("A lent debt round trips through the store")
    func lentDebtRoundTrips() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 0)
        let debt = makeDebt(direction: .lent, principal: 5_000_000, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<Debt>()).first)

        #expect(stored.direction == .lent)
        #expect(stored.principal == 5_000_000)
        #expect(stored.signedPrincipal == -5_000_000)
    }

    @Test("A debt with no due date and no account round trips with neither")
    func openEndedUnlinkedDebtRoundTrips() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let debt = makeDebt(principal: 200_000_000, accountID: nil)

        context.insert(debt)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<Debt>()).first)

        #expect(stored.dueDate == nil)
        #expect(stored.accountID == nil)
    }

    // MARK: - Balances

    @Test("A stored borrowed debt raises the account it names")
    func borrowingRaisesTheAccount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        try context.save()

        #expect(try available(account, in: context) == 40_000_000)
    }

    @Test("A stored lent debt lowers the account it names")
    func lendingLowersTheAccount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(direction: .lent, principal: 4_000_000, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        try context.save()

        #expect(try available(account, in: context) == 6_000_000)
    }

    @Test("A debt naming no account moves no balance at all")
    func anUnlinkedDebtMovesNoBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(principal: 200_000_000, accountID: nil)

        context.insert(account)
        context.insert(debt)
        try context.save()

        #expect(try available(account, in: context) == 10_000_000)
    }

    @Test("Deleting a debt returns the account balance to what it was")
    func deletingADebtRestoresTheBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        try context.save()

        context.delete(debt)
        try context.save()

        #expect(try available(account, in: context) == 10_000_000)
    }

    // MARK: - The cascade

    @Test("Deleting a debt deletes every payment that belonged to it")
    func deletingADebtCascadesToItsPayments() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: account.id)
        let payments = [
            makePayment(5_000_000, debtID: debt.id, accountID: account.id),
            makePayment(7_000_000, debtID: debt.id, accountID: account.id),
        ]

        context.insert(account)
        context.insert(debt)
        payments.forEach(context.insert)
        try context.save()

        // The editor owns the cascade, because the store has no cascade rules.
        for payment in DebtSummary.payments(
            for: debt,
            payments: try context.fetch(FetchDescriptor<DebtPayment>())
        ) {
            context.delete(payment)
        }
        context.delete(debt)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Debt>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<DebtPayment>()).isEmpty)
        #expect(try available(account, in: context) == 10_000_000)
    }

    @Test("Deleting a debt leaves another debt's payments alone")
    func theCascadeSparesOtherDebts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let doomed = makeDebt(principal: 30_000_000, accountID: account.id)
        let survivor = makeDebt(principal: 8_000_000, accountID: account.id)
        let doomedPayment = makePayment(5_000_000, debtID: doomed.id, accountID: account.id)
        let survivingPayment = makePayment(2_000_000, debtID: survivor.id, accountID: account.id)

        context.insert(account)
        context.insert(doomed)
        context.insert(survivor)
        context.insert(doomedPayment)
        context.insert(survivingPayment)
        try context.save()

        for payment in DebtSummary.payments(
            for: doomed,
            payments: try context.fetch(FetchDescriptor<DebtPayment>())
        ) {
            context.delete(payment)
        }
        context.delete(doomed)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<DebtPayment>())

        #expect(remaining.count == 1)
        #expect(remaining.first?.debtID == survivor.id)
    }

    // MARK: - Boundaries

    @Test("A debt is not income or expense, so the Spending totals ignore it")
    func debtsStayOutOfSpending() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let debt = makeDebt(principal: 30_000_000, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())

        #expect(transactions.isEmpty)
        #expect(TransactionSummary.totalIncome(of: transactions) == 0)
        #expect(TransactionSummary.totalExpense(of: transactions) == 0)
    }

    @Test("A debt, a transfer, and a transaction stack on the same account")
    func recordsStackOnOneAccount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let wallet = makeAccount(name: "Wallet", openingBalance: 10_000_000)
        let bank = makeAccount(name: "Bank", openingBalance: 0)
        let debt = makeDebt(principal: 30_000_000, accountID: wallet.id)
        let transfer = AccountTransfer(
            id: UUID(),
            amount: 5_000_000,
            occurredAt: occurredAt,
            note: "",
            sourceAccountID: wallet.id,
            destinationAccountID: bank.id,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )
        let expense = MoneyTransaction(
            id: UUID(),
            kind: .expense,
            amount: 2_000_000,
            occurredAt: occurredAt,
            note: "",
            accountID: wallet.id,
            categoryID: nil,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt
        )

        context.insert(wallet)
        context.insert(bank)
        context.insert(debt)
        context.insert(transfer)
        context.insert(expense)
        try context.save()

        let balance = CashBalanceSummary.available(
            for: wallet,
            deposits: [],
            holdings: [],
            withdrawals: [],
            transactions: try context.fetch(FetchDescriptor<MoneyTransaction>()),
            transfers: try context.fetch(FetchDescriptor<AccountTransfer>()),
            debts: try context.fetch(FetchDescriptor<Debt>()),
            payments: try context.fetch(FetchDescriptor<DebtPayment>()),
            sales: []
        )

        // 10m opening + 30m borrowed − 5m transferred out − 2m spent.
        #expect(balance == 33_000_000)
    }

    @Test("An account named by a debt reports that debt against deletion")
    func anAccountNamedByADebtIsBlocked() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let account = makeAccount(name: "Wallet", openingBalance: 0)
        let debt = makeDebt(principal: 30_000_000, accountID: account.id)
        let payment = makePayment(30_000_000, debtID: debt.id, accountID: account.id)

        context.insert(account)
        context.insert(debt)
        context.insert(payment)
        try context.save()

        let debts = try context.fetch(FetchDescriptor<Debt>())
        let payments = try context.fetch(FetchDescriptor<DebtPayment>())

        // The balance nets to zero, so only the count can block deletion.
        #expect(try available(account, in: context) == 0)
        #expect(DebtSummary.count(for: account, debts: debts, payments: payments) == 2)
    }
}
