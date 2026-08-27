import Foundation
import Testing

@testable import MonMon

/// The suite that makes the module honest. Borrowing, lending, and repaying all
/// move cash and an outstanding balance by the same amount in opposite
/// directions, so none of them may move net worth at all.
@Suite("Net worth is unmoved by borrowing, lending, and repayment")
struct DebtNetWorthTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return DebtInterest.calendar.date(from: components) ?? .distantPast
    }

    private func makeAccount(
        name: String = "Bank",
        kind: CashAccountKind = .normal,
        openingBalance: Decimal = 0
    ) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: name,
            kind: kind,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    private func makeDebt(
        direction: DebtDirection = .borrowed,
        principal: Decimal,
        rate: Decimal = 0,
        dueDate: Date? = nil,
        account: CashAccount?
    ) -> Debt {
        Debt(
            id: UUID(),
            counterparty: "Anh Minh",
            direction: direction,
            principal: principal,
            annualInterestRate: rate,
            openedAt: createdAt,
            dueDate: dueDate,
            accountID: account?.id,
            note: "",
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    private func makePayment(
        _ amount: Decimal,
        on debt: Debt,
        from account: CashAccount
    ) -> DebtPayment {
        DebtPayment(
            id: UUID(),
            debtID: debt.id,
            amount: amount,
            occurredAt: createdAt,
            accountID: account.id,
            note: "",
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    private func netWorth(
        _ accounts: [CashAccount],
        debts: [Debt] = [],
        payments: [DebtPayment] = []
    ) -> Decimal {
        AssetSummary.netWorth(
            accounts: accounts,
            deposits: [],
            withdrawals: [],
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: [],
            debts: debts,
            payments: payments,
            sales: []
        )
    }

    private func available(
        _ account: CashAccount,
        debts: [Debt] = [],
        payments: [DebtPayment] = []
    ) -> Decimal {
        CashBalanceSummary.available(
            for: account,
            deposits: [],
            holdings: [],
            withdrawals: [],
            transactions: [],
            transfers: [],
            debts: debts,
            payments: payments,
            sales: []
        )
    }

    private func slices(
        _ accounts: [CashAccount],
        debts: [Debt] = [],
        payments: [DebtPayment] = []
    ) -> [AssetAllocationSlice] {
        AssetAllocation.slices(
            accounts: accounts,
            deposits: [],
            withdrawals: [],
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: [],
            debts: debts,
            payments: payments,
            sales: []
        )
    }

    private func liabilities(
        _ accounts: [CashAccount],
        debts: [Debt] = [],
        payments: [DebtPayment] = []
    ) -> Decimal {
        AssetAllocation.liabilities(
            accounts: accounts,
            deposits: [],
            withdrawals: [],
            holdings: [],
            transactions: [],
            transfers: [],
            debts: debts,
            payments: payments,
            sales: []
        )
    }

    // MARK: - The four moves

    @Test("Borrowing leaves net worth exactly where it was")
    func borrowingDoesNotMoveNetWorth() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let debt = makeDebt(principal: 50_000_000, account: bank)

        #expect(netWorth([bank]) == 100_000_000)
        #expect(available(bank, debts: [debt]) == 150_000_000)
        #expect(netWorth([bank], debts: [debt]) == 100_000_000)
    }

    @Test("Lending leaves net worth exactly where it was")
    func lendingDoesNotMoveNetWorth() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let debt = makeDebt(direction: .lent, principal: 30_000_000, account: bank)

        #expect(available(bank, debts: [debt]) == 70_000_000)
        #expect(netWorth([bank], debts: [debt]) == 100_000_000)
    }

    @Test("Repaying part of a borrowed debt leaves net worth exactly where it was")
    func partialRepaymentDoesNotMoveNetWorth() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let debt = makeDebt(principal: 50_000_000, account: bank)
        let payments = [makePayment(20_000_000, on: debt, from: bank)]

        #expect(available(bank, debts: [debt], payments: payments) == 130_000_000)
        #expect(
            DebtSummary.totalOutstanding(
                of: [debt],
                payments: payments,
                direction: .borrowed
            ) == 30_000_000
        )
        #expect(netWorth([bank], debts: [debt], payments: payments) == 100_000_000)
    }

    @Test("Repaying a borrowed debt in full leaves net worth exactly where it was")
    func fullRepaymentDoesNotMoveNetWorth() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let debt = makeDebt(principal: 50_000_000, account: bank)
        let payments = [makePayment(50_000_000, on: debt, from: bank)]

        // Back to the pre-borrow balance, as it must be.
        #expect(available(bank, debts: [debt], payments: payments) == 100_000_000)
        #expect(netWorth([bank], debts: [debt], payments: payments) == 100_000_000)
    }

    @Test("Being repaid on a lent debt leaves net worth exactly where it was")
    func beingRepaidDoesNotMoveNetWorth() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let debt = makeDebt(direction: .lent, principal: 30_000_000, account: bank)
        let payments = [makePayment(10_000_000, on: debt, from: bank)]

        #expect(available(bank, debts: [debt], payments: payments) == 80_000_000)
        #expect(
            DebtSummary.totalOutstanding(
                of: [debt],
                payments: payments,
                direction: .lent
            ) == 20_000_000
        )
        #expect(netWorth([bank], debts: [debt], payments: payments) == 100_000_000)
    }

    @Test("Borrowing and then lending the same money leaves net worth exactly where it was")
    func borrowingThenLendingDoesNotMoveNetWorth() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let borrowed = makeDebt(principal: 50_000_000, account: bank)
        let lent = makeDebt(direction: .lent, principal: 50_000_000, account: bank)
        let debts = [borrowed, lent]

        #expect(available(bank, debts: debts) == 100_000_000)
        #expect(netWorth([bank], debts: debts) == 100_000_000)
    }

    @Test("Borrowing into one account and repaying from another leaves net worth alone")
    func repayingFromAnotherAccountDoesNotMoveNetWorth() {
        let wallet = makeAccount(name: "Wallet", kind: .normal, openingBalance: 40_000_000)
        let bank = makeAccount(openingBalance: 100_000_000)
        let debt = makeDebt(principal: 50_000_000, account: wallet)
        let payments = [makePayment(50_000_000, on: debt, from: bank)]
        let accounts = [wallet, bank]

        #expect(available(wallet, debts: [debt], payments: payments) == 90_000_000)
        #expect(available(bank, debts: [debt], payments: payments) == 50_000_000)
        #expect(netWorth(accounts, debts: [debt], payments: payments) == 140_000_000)
    }

    @Test("A debt naming no account lowers net worth and moves no balance")
    func anUnlinkedDebtLowersNetWorthAlone() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let debt = makeDebt(principal: 50_000_000, account: nil)

        // Correct, and the whole reason the account is optional: stating a
        // previously untracked obligation makes the owner poorer on paper,
        // because the borrowed money was spent before tracking began.
        #expect(available(bank, debts: [debt]) == 100_000_000)
        #expect(netWorth([bank], debts: [debt]) == 50_000_000)
    }

    // MARK: - Interest

    @Test("Projected interest on a debt never reaches net worth")
    func projectedInterestStaysOutOfNetWorth() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let free = makeDebt(principal: 50_000_000, account: bank)
        let charged = makeDebt(
            principal: 50_000_000,
            rate: 12,
            dueDate: date(2024, 11, 14),
            account: bank
        )

        #expect(charged.projectedInterest(asOf: createdAt) > 0)
        #expect(netWorth([bank], debts: [charged]) == netWorth([bank], debts: [free]))
    }

    // MARK: - The ring

    @Test("Money lent out is drawn as its own wedge")
    func lentMoneyBecomesAWedge() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let debt = makeDebt(direction: .lent, principal: 30_000_000, account: bank)
        let drawn = slices([bank], debts: [debt])

        #expect(drawn.map(\.kind) == [.cash, .lent])
        #expect(drawn.map(\.amount) == [70_000_000, 30_000_000])
    }

    @Test("Borrowed money never becomes a wedge")
    func borrowedMoneyIsNeverAWedge() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let debt = makeDebt(principal: 50_000_000, account: bank)
        let drawn = slices([bank], debts: [debt])

        #expect(drawn.map(\.kind) == [.cash])
        #expect(liabilities([bank], debts: [debt]) == 50_000_000)
    }

    @Test("A settled debt leaves both the ring and the owed figure alone")
    func aSettledDebtDrawsNothing() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let borrowed = makeDebt(principal: 50_000_000, account: bank)
        let lent = makeDebt(direction: .lent, principal: 30_000_000, account: bank)
        let debts = [borrowed, lent]
        let payments = [
            makePayment(50_000_000, on: borrowed, from: bank),
            makePayment(30_000_000, on: lent, from: bank),
        ]
        let drawn = slices([bank], debts: debts, payments: payments)

        #expect(drawn.map(\.kind) == [.cash])
        #expect(liabilities([bank], debts: debts, payments: payments) == 0)
        #expect(netWorth([bank], debts: debts, payments: payments) == 100_000_000)
    }

    @Test("Borrowed money and an overdrawn card are owed together")
    func overdraftAndBorrowingAddUp() {
        let card = makeAccount(name: "Visa", kind: .credit, openingBalance: -20_000_000)
        let debt = makeDebt(principal: 50_000_000, account: nil)
        let accounts = [card]

        let overdraft = AssetAllocation.overdraft(
            accounts: accounts,
            deposits: [],
            withdrawals: [],
            holdings: [],
            transactions: [],
            transfers: [],
            debts: [debt],
            payments: [],
            sales: []
        )

        // Two separate obligations, summed once each.
        #expect(overdraft == 20_000_000)
        #expect(liabilities(accounts, debts: [debt]) == 70_000_000)
        #expect(netWorth(accounts, debts: [debt]) == -70_000_000)
    }

    @Test("The ring total minus what is owed still equals net worth")
    func ringMinusLiabilitiesIsNetWorth() {
        let wallet = makeAccount(name: "Wallet", kind: .normal, openingBalance: 60_000_000)
        let card = makeAccount(name: "Visa", kind: .credit, openingBalance: -5_000_000)
        let accounts = [wallet, card]
        let debts = [
            makeDebt(principal: 40_000_000, account: wallet),
            makeDebt(direction: .lent, principal: 25_000_000, account: wallet),
            makeDebt(principal: 200_000_000, account: nil),
        ]
        let payments = [makePayment(10_000_000, on: debts[0], from: wallet)]

        let drawn = slices(accounts, debts: debts, payments: payments)
        let owed = liabilities(accounts, debts: debts, payments: payments)

        #expect(
            AssetAllocation.total(of: drawn) - owed
                == netWorth(accounts, debts: debts, payments: payments)
        )
    }

    @Test("Spendable cash falls by what is lent and rises by what is borrowed")
    func spendableCashFollowsTheDirection() {
        let bank = makeAccount(openingBalance: 100_000_000)
        let borrowed = makeDebt(principal: 50_000_000, account: bank)
        let lent = makeDebt(direction: .lent, principal: 30_000_000, account: bank)

        let cash = { (debts: [Debt]) in
            AssetAllocation.positiveCash(
                accounts: [bank],
                deposits: [],
                withdrawals: [],
                holdings: [],
                transactions: [],
                transfers: [],
                debts: debts,
                payments: [],
                sales: []
            )
        }

        #expect(cash([borrowed]) == 150_000_000)
        #expect(cash([lent]) == 70_000_000)
    }
}
