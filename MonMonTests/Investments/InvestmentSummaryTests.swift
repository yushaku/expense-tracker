import Foundation
import Testing

@testable import MonMon

@Suite("Investment summary")
struct InvestmentSummaryTests {
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

    private func makeDeposit(principal: Decimal, sourceAccountID: UUID? = nil) -> SavingsDeposit {
        SavingsDeposit(
            id: UUID(),
            name: "Deposit",
            principal: principal,
            annualInterestRate: 6,
            termMonths: 12,
            openedAt: openedAt,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt,
            sourceAccountID: sourceAccountID
        )
    }

    private func makeHolding(
        units: Decimal,
        averageCostPerUnit: Decimal,
        currentNAVPerUnit: Decimal,
        sourceAccountID: UUID? = nil
    ) -> FundHolding {
        FundHolding(
            id: UUID(),
            name: "Holding",
            symbol: "VESAF",
            kind: .fund,
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            currentNAVPerUnit: currentNAVPerUnit,
            navAsOf: openedAt,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt,
            sourceAccountID: sourceAccountID
        )
    }

    @Test("Nothing parked totals zero")
    func emptyTotalsZero() {
        #expect(InvestmentSummary.total(deposits: [], holdings: []) == 0)
    }

    @Test("Deposits alone total their principal, not their maturity value")
    func depositsTotalPrincipal() {
        let deposits = [makeDeposit(principal: 100_000_000), makeDeposit(principal: 50_000_000)]

        #expect(InvestmentSummary.total(deposits: deposits, holdings: []) == 150_000_000)
    }

    @Test("Holdings alone total their market value, so an unrealized gain shows")
    func holdingsTotalMarketValue() {
        let holdings = [
            makeHolding(units: 1_000, averageCostPerUnit: 20_000, currentNAVPerUnit: 25_000)
        ]

        // Cost basis is 20.000.000 ₫; the figure follows today's NAV instead.
        #expect(FundSummary.totalCostBasis(of: holdings) == 20_000_000)
        #expect(InvestmentSummary.total(deposits: [], holdings: holdings) == 25_000_000)
    }

    @Test("Both halves add together")
    func bothHalvesAdd() {
        let deposits = [makeDeposit(principal: 100_000_000)]
        let holdings = [
            makeHolding(units: 1_000, averageCostPerUnit: 20_000, currentNAVPerUnit: 25_000)
        ]

        #expect(InvestmentSummary.total(deposits: deposits, holdings: holdings) == 125_000_000)
    }

    /// The screen's total and Home's net worth read the same records, so the
    /// gap between them must be exactly the spendable cash and nothing else.
    @Test("The total is net worth less spendable cash")
    func totalIsNetWorthLessSpendableCash() {
        let account = makeAccount(openingBalance: 500_000_000)
        let deposits = [makeDeposit(principal: 100_000_000, sourceAccountID: account.id)]
        let holdings = [
            makeHolding(
                units: 1_000,
                averageCostPerUnit: 20_000,
                currentNAVPerUnit: 25_000,
                sourceAccountID: account.id
            )
        ]

        let spendable = CashBalanceSummary.totalAvailable(
            of: [account],
            deposits: deposits,
            holdings: holdings,
            transactions: [],
            transfers: [],
            debts: [],
            payments: []
        )
        let netWorth = AssetSummary.netWorth(
            accounts: [account],
            deposits: deposits,
            holdings: holdings,
            transactions: [],
            transfers: [],
            debts: [],
            payments: []
        )

        #expect(
            InvestmentSummary.total(deposits: deposits, holdings: holdings)
                == netWorth - spendable
        )
    }
}
