import Foundation
import Testing

@testable import MonMon

@Suite("Asset summary")
struct AssetSummaryTests {
    private let openedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeAccount(openingBalance: Decimal) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: "Techcombank",
            kind: .bank,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt
        )
    }

    private func makeDeposit(
        principal: Decimal,
        rate: Decimal = 6,
        termMonths: Int = 12,
        sourceAccountID: UUID? = nil
    ) -> SavingsDeposit {
        SavingsDeposit(
            id: UUID(),
            name: "Deposit",
            principal: principal,
            annualInterestRate: rate,
            termMonths: termMonths,
            openedAt: openedAt,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt,
            sourceAccountID: sourceAccountID
        )
    }

    @Test("No deposits total to zero")
    func emptyDepositsTotalZero() {
        #expect(AssetSummary.totalPrincipal(of: []) == 0)
        #expect(AssetSummary.totalProjectedInterest(of: []) == 0)
        #expect(AssetSummary.totalMaturityValue(of: []) == 0)
    }

    @Test("Multiple deposit principals add exactly")
    func principalsAddExactly() {
        let deposits = [
            makeDeposit(principal: 100_000_000),
            makeDeposit(principal: 250_000_000),
            makeDeposit(principal: 1_500_000),
        ]

        #expect(AssetSummary.totalPrincipal(of: deposits) == 351_500_000)
    }

    @Test("Projected interest sums each deposit's own term")
    func projectedInterestSums() {
        let deposits = [
            makeDeposit(principal: 100_000_000, rate: 6, termMonths: 12),
            makeDeposit(principal: 200_000_000, rate: 6, termMonths: 12),
        ]
        let expected = deposits.reduce(Decimal.zero) { $0 + $1.projectedInterest }

        #expect(AssetSummary.totalProjectedInterest(of: deposits) == expected)
        #expect(expected > 0)
    }

    @Test("An unfunded account keeps its full opening balance available")
    func unfundedAccountIsFullyAvailable() {
        let account = makeAccount(openingBalance: 148_900_000)
        let unrelated = makeDeposit(principal: 100_000_000, sourceAccountID: UUID())

        #expect(CashBalanceSummary.fundedAmount(for: account, deposits: [unrelated]) == 0)
        #expect(
            CashBalanceSummary.available(for: account, deposits: [unrelated])
                == 148_900_000
        )
    }

    @Test("A funded account reports the deposited principal as unavailable")
    func fundedAccountReducesAvailableBalance() {
        let account = makeAccount(openingBalance: 148_900_000)
        let deposit = makeDeposit(principal: 100_000_000, sourceAccountID: account.id)

        #expect(
            CashBalanceSummary.fundedAmount(for: account, deposits: [deposit])
                == 100_000_000
        )
        #expect(
            CashBalanceSummary.available(for: account, deposits: [deposit]) == 48_900_000
        )
        #expect(CashBalanceSummary.total(of: [account]) == 148_900_000)
    }

    @Test("Several deposits from one account all reduce its available balance")
    func severalDepositsReduceAvailableBalance() {
        let account = makeAccount(openingBalance: 148_900_000)
        let deposits = [
            makeDeposit(principal: 100_000_000, sourceAccountID: account.id),
            makeDeposit(principal: 40_000_000, sourceAccountID: account.id),
        ]

        #expect(
            CashBalanceSummary.available(for: account, deposits: deposits) == 8_900_000
        )
        #expect(
            CashBalanceSummary.totalAvailable(of: [account], deposits: deposits)
                == 8_900_000
        )
    }

    @Test("Net worth counts money moved into a deposit exactly once")
    func netWorthDoesNotDoubleCount() {
        let account = makeAccount(openingBalance: 148_900_000)
        let funded = makeDeposit(principal: 100_000_000, sourceAccountID: account.id)

        #expect(AssetSummary.netWorth(accounts: [account], deposits: [funded]) == 148_900_000)
    }

    @Test("A deposit without a source account adds to net worth")
    func unfundedDepositAddsToNetWorth() {
        let account = makeAccount(openingBalance: 148_900_000)
        let external = makeDeposit(principal: 250_000_000)

        #expect(
            AssetSummary.netWorth(accounts: [account], deposits: [external])
                == 398_900_000
        )
    }
}
