import Foundation
import Testing

@testable import MonMon

@Suite("Debt outstanding balances and cash flow")
struct DebtSummaryTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return DebtInterest.calendar.date(from: components) ?? .distantPast
    }

    private func makeAccount(
        name: String = "Wallet",
        kind: CashAccountKind = .cash,
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
        principal: Decimal = 10_000_000,
        rate: Decimal = 0,
        openedAt: Date? = nil,
        dueDate: Date? = nil,
        account: CashAccount? = nil
    ) -> Debt {
        Debt(
            id: UUID(),
            counterparty: "Anh Minh",
            direction: direction,
            principal: principal,
            annualInterestRate: rate,
            openedAt: openedAt ?? createdAt,
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
        from account: CashAccount,
        occurredAt: Date? = nil
    ) -> DebtPayment {
        DebtPayment(
            id: UUID(),
            debtID: debt.id,
            amount: amount,
            occurredAt: occurredAt ?? createdAt,
            accountID: account.id,
            note: "",
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    // MARK: - Outstanding

    @Test("A debt with no payments is outstanding in full")
    func untouchedDebtIsOutstandingInFull() {
        let debt = makeDebt(principal: 10_000_000)

        #expect(DebtSummary.outstanding(for: debt, payments: []) == 10_000_000)
        #expect(DebtSummary.paid(for: debt, payments: []) == 0)
        #expect(DebtSummary.isSettled(debt, payments: []) == false)
    }

    @Test("Payments reduce what is outstanding")
    func paymentsReduceOutstanding() {
        let wallet = makeAccount()
        let debt = makeDebt(principal: 10_000_000)
        let payments = [makePayment(3_000_000, on: debt, from: wallet)]

        #expect(DebtSummary.paid(for: debt, payments: payments) == 3_000_000)
        #expect(DebtSummary.outstanding(for: debt, payments: payments) == 7_000_000)
    }

    @Test("A fully repaid debt is outstanding nothing and reads as settled")
    func fullRepaymentSettles() {
        let wallet = makeAccount()
        let debt = makeDebt(principal: 10_000_000)
        let payments = [
            makePayment(4_000_000, on: debt, from: wallet),
            makePayment(6_000_000, on: debt, from: wallet),
        ]

        #expect(DebtSummary.outstanding(for: debt, payments: payments) == 0)
        #expect(DebtSummary.isSettled(debt, payments: payments))
    }

    @Test("Only the payments belonging to a debt count against it")
    func paymentsDoNotCrossDebts() {
        let wallet = makeAccount()
        let mine = makeDebt(principal: 10_000_000)
        let other = makeDebt(principal: 5_000_000)
        let payments = [
            makePayment(3_000_000, on: mine, from: wallet),
            makePayment(5_000_000, on: other, from: wallet),
        ]

        #expect(DebtSummary.outstanding(for: mine, payments: payments) == 7_000_000)
        #expect(DebtSummary.outstanding(for: other, payments: payments) == 0)
        #expect(DebtSummary.payments(for: mine, payments: payments).count == 1)
    }

    @Test("Progress runs from nothing to whole and never divides by zero")
    func progressIsBounded() {
        let wallet = makeAccount()
        let debt = makeDebt(principal: 10_000_000)
        let half = [makePayment(5_000_000, on: debt, from: wallet)]
        let whole = [makePayment(10_000_000, on: debt, from: wallet)]
        let free = makeDebt(principal: 0)

        #expect(DebtSummary.progress(for: debt, payments: []) == 0)
        #expect(DebtSummary.progress(for: debt, payments: half) == Decimal(string: "0.5"))
        #expect(DebtSummary.progress(for: debt, payments: whole) == 1)
        #expect(DebtSummary.progress(for: free, payments: []) == 0)
    }

    // MARK: - The four signed cases

    @Test("Borrowing raises the account it names and lending lowers it")
    func openingMovesTheNamedAccount() {
        let wallet = makeAccount()
        let borrowed = makeDebt(direction: .borrowed, principal: 10_000_000, account: wallet)
        let lent = makeDebt(direction: .lent, principal: 4_000_000, account: wallet)

        #expect(borrowed.signedPrincipal == 10_000_000)
        #expect(lent.signedPrincipal == -4_000_000)
        #expect(DebtSummary.netFlow(for: wallet, debts: [borrowed], payments: []) == 10_000_000)
        #expect(DebtSummary.netFlow(for: wallet, debts: [lent], payments: []) == -4_000_000)
    }

    @Test("Repaying lowers the account and being repaid raises it")
    func paymentsReverseTheirDebt() {
        let wallet = makeAccount()
        let borrowed = makeDebt(direction: .borrowed, principal: 10_000_000, account: wallet)
        let lent = makeDebt(direction: .lent, principal: 4_000_000, account: wallet)
        let repayment = makePayment(2_000_000, on: borrowed, from: wallet)
        let receipt = makePayment(1_000_000, on: lent, from: wallet)

        #expect(repayment.signedAmount(for: .borrowed) == -2_000_000)
        #expect(receipt.signedAmount(for: .lent) == 1_000_000)
        #expect(
            DebtSummary.netFlow(for: wallet, debts: [borrowed], payments: [repayment])
                == 8_000_000
        )
        #expect(
            DebtSummary.netFlow(for: wallet, debts: [lent], payments: [receipt]) == -3_000_000
        )
    }

    @Test("A debt moves no account but the one it names")
    func otherAccountsAreUntouched() {
        let wallet = makeAccount(name: "Wallet")
        let bank = makeAccount(name: "Bank", kind: .bank)
        let debt = makeDebt(principal: 10_000_000, account: wallet)
        let payments = [makePayment(2_000_000, on: debt, from: wallet)]

        #expect(DebtSummary.netFlow(for: bank, debts: [debt], payments: payments) == 0)
    }

    @Test("A debt that names no account moves nothing at all")
    func anUnlinkedDebtMovesNothing() {
        let wallet = makeAccount()
        let debt = makeDebt(principal: 200_000_000, account: nil)

        #expect(debt.signedPrincipal(for: wallet.id) == 0)
        #expect(DebtSummary.netFlow(for: wallet, debts: [debt], payments: []) == 0)
        #expect(DebtSummary.count(for: wallet, debts: [debt], payments: []) == 0)
    }

    @Test("A debt repaid in full nets to nothing on the account that opened it")
    func fullRepaymentNetsToZero() {
        let wallet = makeAccount()
        let debt = makeDebt(principal: 10_000_000, account: wallet)
        let payments = [makePayment(10_000_000, on: debt, from: wallet)]

        #expect(DebtSummary.netFlow(for: wallet, debts: [debt], payments: payments) == 0)
    }

    @Test("A debt repaid from a different account moves both and leaves the pair unchanged")
    func repaymentFromAnotherAccountMovesBoth() {
        let wallet = makeAccount(name: "Wallet")
        let bank = makeAccount(name: "Bank", kind: .bank)
        let debt = makeDebt(principal: 10_000_000, account: wallet)
        let payments = [makePayment(10_000_000, on: debt, from: bank)]

        let onWallet = DebtSummary.netFlow(for: wallet, debts: [debt], payments: payments)
        let onBank = DebtSummary.netFlow(for: bank, debts: [debt], payments: payments)

        #expect(onWallet == 10_000_000)
        #expect(onBank == -10_000_000)
        #expect(onWallet + onBank == 0)
    }

    @Test("A payment naming no live debt moves no balance")
    func anOrphanedPaymentIsSkipped() {
        let wallet = makeAccount()
        let deleted = makeDebt(principal: 10_000_000, account: wallet)
        let payments = [makePayment(2_000_000, on: deleted, from: wallet)]

        // The debt is gone from the snapshot; its payment must not be signed by
        // guesswork, so it moves nothing.
        #expect(DebtSummary.netFlow(for: wallet, debts: [], payments: payments) == 0)
    }

    // MARK: - Totals

    @Test("Debt lists only include the selected direction")
    func debtsMatchSelectedDirection() {
        let borrowed = makeDebt(direction: .borrowed)
        let lent = makeDebt(direction: .lent)

        #expect(DebtSummary.matching([borrowed, lent], direction: .borrowed) == [borrowed])
        #expect(DebtSummary.matching([borrowed, lent], direction: .lent) == [lent])
    }

    @Test("Totals are counted per direction")
    func totalsSplitByDirection() {
        let wallet = makeAccount()
        let borrowed = makeDebt(direction: .borrowed, principal: 10_000_000, account: wallet)
        let lent = makeDebt(direction: .lent, principal: 4_000_000, account: wallet)
        let debts = [borrowed, lent]
        let payments = [makePayment(3_000_000, on: borrowed, from: wallet)]

        #expect(DebtSummary.totalPrincipal(of: debts, direction: .borrowed) == 10_000_000)
        #expect(DebtSummary.totalPrincipal(of: debts, direction: .lent) == 4_000_000)
        #expect(
            DebtSummary.totalOutstanding(of: debts, payments: payments, direction: .borrowed)
                == 7_000_000
        )
        #expect(
            DebtSummary.totalOutstanding(of: debts, payments: payments, direction: .lent)
                == 4_000_000
        )
    }

    @Test("A settled debt no longer counts towards total outstanding")
    func settledDebtsLeaveTheTotal() {
        let wallet = makeAccount()
        let debt = makeDebt(principal: 10_000_000, account: wallet)
        let payments = [makePayment(10_000_000, on: debt, from: wallet)]

        #expect(
            DebtSummary.totalOutstanding(
                of: [debt],
                payments: payments,
                direction: .borrowed
            ) == 0
        )
    }

    @Test("Both a debt and its payments count towards the account that owns them")
    func deletionGuardCountsBoth() {
        let wallet = makeAccount()
        let debt = makeDebt(principal: 10_000_000, account: wallet)
        let payments = [makePayment(10_000_000, on: debt, from: wallet)]

        // The balance nets to zero, so only the count can block deletion.
        #expect(DebtSummary.netFlow(for: wallet, debts: [debt], payments: payments) == 0)
        #expect(DebtSummary.count(for: wallet, debts: [debt], payments: payments) == 2)
    }

    // MARK: - Overdue

    @Test("A debt is overdue only once its due date has passed and it is still owed")
    func overdueNeedsBothConditions() {
        let debt = makeDebt(
            principal: 10_000_000,
            openedAt: date(2026, 1, 1),
            dueDate: date(2026, 6, 1)
        )

        #expect(DebtSummary.isOverdue(debt, payments: [], asOf: date(2026, 5, 1)) == false)
        #expect(DebtSummary.isOverdue(debt, payments: [], asOf: date(2026, 6, 2)))
    }

    @Test("A settled debt is never overdue")
    func settledIsNeverOverdue() {
        let wallet = makeAccount()
        let debt = makeDebt(
            principal: 10_000_000,
            openedAt: date(2026, 1, 1),
            dueDate: date(2026, 6, 1)
        )
        let payments = [makePayment(10_000_000, on: debt, from: wallet)]

        #expect(DebtSummary.isOverdue(debt, payments: payments, asOf: date(2027, 1, 1)) == false)
    }

    @Test("A debt with no due date is never overdue")
    func openEndedIsNeverOverdue() {
        let debt = makeDebt(principal: 10_000_000, openedAt: date(2026, 1, 1))

        #expect(DebtSummary.isOverdue(debt, payments: [], asOf: date(2030, 1, 1)) == false)
    }

    // MARK: - Display ordering

    @Test("Open debts lead by due date, undated follow, and settled debts finish")
    func displayOrderPrioritizesActionableDebts() {
        let wallet = makeAccount()
        let dueLater = makeDebt(dueDate: date(2026, 8, 1))
        let settled = makeDebt(dueDate: date(2026, 5, 1))
        let undated = makeDebt()
        let dueSooner = makeDebt(dueDate: date(2026, 6, 1))
        let payments = [makePayment(10_000_000, on: settled, from: wallet)]

        let ordered = DebtSummary.sortedForDisplay(
            [settled, undated, dueLater, dueSooner],
            payments: payments
        )

        #expect(ordered.map(\.id) == [dueSooner.id, dueLater.id, undated.id, settled.id])
    }

    // MARK: - Range filtering

    @Test("Range filtering keeps only the debts and payments inside it")
    func rangeFilteringNarrowsBoth() {
        let wallet = makeAccount()
        let inside = makeDebt(principal: 1_000_000, openedAt: date(2026, 3, 10), account: wallet)
        let outside = makeDebt(principal: 1_000_000, openedAt: date(2026, 4, 10), account: wallet)
        let range = TransactionRange.month(containing: date(2026, 3, 15))
        let payments = [
            makePayment(100_000, on: inside, from: wallet, occurredAt: date(2026, 3, 20)),
            makePayment(100_000, on: inside, from: wallet, occurredAt: date(2026, 4, 20)),
        ]

        #expect(DebtSummary.inRange(range, debts: [inside, outside]).count == 1)
        #expect(DebtSummary.inRange(range, payments: payments).count == 1)
    }
}
