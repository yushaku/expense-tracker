import Foundation
import Testing

@testable import MonMon

@Suite("Savings withdrawal summary")
struct SavingsWithdrawalSummaryTests {
    private let openedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDeposit(principal: Decimal = 100_000_000) -> SavingsDeposit {
        SavingsDeposit(
            id: UUID(),
            name: "Deposit",
            principal: principal,
            annualInterestRate: 6,
            termMonths: 12,
            openedAt: openedAt,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt
        )
    }

    private func makeWithdrawal(
        from deposit: SavingsDeposit,
        principal: Decimal,
        received: Decimal,
        accountID: UUID = UUID(),
        withdrawnAt: Date? = nil
    ) -> SavingsWithdrawal {
        SavingsWithdrawal(
            id: UUID(),
            depositID: deposit.id,
            principal: principal,
            amountReceived: received,
            destinationAccountID: accountID,
            withdrawnAt: withdrawnAt ?? openedAt.addingTimeInterval(86_400),
            createdAt: openedAt.addingTimeInterval(86_400)
        )
    }

    @Test("A partial withdrawal reduces only the remaining principal")
    func partialWithdrawalReducesPrincipal() {
        let deposit = makeDeposit()
        let withdrawal = makeWithdrawal(
            from: deposit,
            principal: 30_000_000,
            received: 30_100_000
        )

        #expect(deposit.remainingPrincipal(withdrawals: [withdrawal]) == 70_000_000)
        #expect(deposit.principal == 100_000_000)
        #expect(withdrawal.realizedInterest == 100_000)
    }

    @Test("A full withdrawal settles the deposit")
    func fullWithdrawalSettlesDeposit() {
        let deposit = makeDeposit()
        let withdrawal = makeWithdrawal(
            from: deposit,
            principal: 100_000_000,
            received: 100_500_000
        )

        #expect(deposit.status(withdrawals: [withdrawal], asOf: deposit.maturityDate) == .settled)
        #expect(deposit.remainingPrincipal(withdrawals: [withdrawal]) == 0)
    }

    @Test("An untouched deposit becomes matured without moving money")
    func maturityDoesNotSettleAutomatically() {
        let deposit = makeDeposit()

        #expect(
            deposit.status(
                withdrawals: [],
                asOf: deposit.maturityDate.addingTimeInterval(1)
            ) == .matured
        )
        #expect(deposit.remainingPrincipal(withdrawals: []) == deposit.principal)
    }

    @Test("Withdrawal proceeds land only in their destination account")
    func proceedsLandInDestinationAccount() {
        let deposit = makeDeposit()
        let destinationID = UUID()
        let withdrawal = makeWithdrawal(
            from: deposit,
            principal: 30_000_000,
            received: 30_100_000,
            accountID: destinationID
        )
        let destination = CashAccount(
            id: destinationID,
            name: "Wallet",
            kind: .cash,
            openingBalance: 0,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt
        )
        let other = CashAccount(
            id: UUID(),
            name: "Bank",
            kind: .bank,
            openingBalance: 0,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt
        )

        #expect(SavingsWithdrawalSummary.netFlow(for: destination, withdrawals: [withdrawal]) == 30_100_000)
        #expect(SavingsWithdrawalSummary.netFlow(for: other, withdrawals: [withdrawal]) == 0)
    }

    @Test("Projected interest follows the principal still deposited")
    func projectedInterestUsesRemainingPrincipal() {
        let deposit = makeDeposit()
        let withdrawal = makeWithdrawal(
            from: deposit,
            principal: 40_000_000,
            received: 40_000_000
        )

        let expected = SavingsInterest.projectedInterest(
            principal: 60_000_000,
            annualRatePercent: deposit.annualInterestRate,
            days: deposit.termDayCount
        )

        #expect(deposit.projectedInterest(withdrawals: [withdrawal]) == expected)
    }
}
