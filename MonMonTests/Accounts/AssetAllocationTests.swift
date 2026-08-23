import Foundation
import Testing

@testable import MonMon

@Suite("Asset allocation")
struct AssetAllocationTests {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeAccount(openingBalance: Decimal) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: "Account",
            kind: .cash,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: fixedDate
        )
    }

    private func makeDeposit(principal: Decimal, sourceAccountID: UUID? = nil) -> SavingsDeposit {
        SavingsDeposit(
            id: UUID(),
            name: "Techcombank",
            principal: principal,
            annualInterestRate: 6,
            termMonths: 6,
            openedAt: fixedDate,
            currencyCode: VNDCurrency.code,
            createdAt: fixedDate,
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
            name: "VESAF",
            symbol: "VESAF",
            kind: .fund,
            units: units,
            averageCostPerUnit: averageCostPerUnit,
            currentNAVPerUnit: currentNAVPerUnit,
            navAsOf: fixedDate,
            currencyCode: VNDCurrency.code,
            createdAt: fixedDate,
            sourceAccountID: sourceAccountID
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
            currencyCode: VNDCurrency.code,
            createdAt: fixedDate
        )
    }

    @Test("Nothing held produces no wedges")
    func emptyPortfolioHasNoSlices() {
        let slices = AssetAllocation.slices(
            accounts: [],
            deposits: [],
            holdings: [],
            transactions: []
        )

        #expect(slices.isEmpty)
        #expect(AssetAllocation.total(of: slices) == 0)
    }

    @Test("The three groups are split and ordered largest first")
    func groupsAreSplitAndOrdered() {
        let account = makeAccount(openingBalance: 200_000_000)
        let deposit = makeDeposit(principal: 100_000_000, sourceAccountID: account.id)
        let holding = makeHolding(
            units: 1_000,
            averageCostPerUnit: 20_000,
            currentNAVPerUnit: 25_000,
            sourceAccountID: account.id
        )

        let slices = AssetAllocation.slices(
            accounts: [account],
            deposits: [deposit],
            holdings: [holding],
            transactions: []
        )

        // 200.000.000 − 100.000.000 deposited − 20.000.000 invested = 80.000.000
        #expect(slices.map(\.kind) == [.savings, .cash, .funds])
        #expect(slices.map(\.amount) == [100_000_000, 80_000_000, 25_000_000])
    }

    @Test("A group holding nothing is left out of the ring")
    func emptyGroupIsDropped() {
        let account = makeAccount(openingBalance: 1_250_000)

        let slices = AssetAllocation.slices(
            accounts: [account],
            deposits: [],
            holdings: [],
            transactions: []
        )

        #expect(slices.map(\.kind) == [.cash])
    }

    @Test("Recorded flow reaches the cash wedge")
    func flowMovesTheCashSlice() {
        let account = makeAccount(openingBalance: 10_000_000)
        let transactions = [
            makeTransaction(kind: .expense, amount: 200_000, accountID: account.id)
        ]

        let slices = AssetAllocation.slices(
            accounts: [account],
            deposits: [],
            holdings: [],
            transactions: transactions
        )

        #expect(slices.first?.amount == 9_800_000)
    }

    @Test("An overdrawn account leaves the ring and is reported as debt")
    func overdrawnAccountBecomesDebt() {
        let wallet = makeAccount(openingBalance: 10_000_000)
        let card = makeAccount(openingBalance: -5_200_000)

        let slices = AssetAllocation.slices(
            accounts: [wallet, card],
            deposits: [],
            holdings: [],
            transactions: []
        )
        let debt = AssetAllocation.debt(
            accounts: [wallet, card],
            deposits: [],
            holdings: [],
            transactions: []
        )

        // The ring shows only what is held; the card is not netted off it.
        #expect(slices.map(\.amount) == [10_000_000])
        #expect(debt == 5_200_000)
    }

    @Test("The ring total minus debt equals net worth")
    func ringMinusDebtIsNetWorth() {
        let wallet = makeAccount(openingBalance: 60_000_000)
        let card = makeAccount(openingBalance: -5_000_000)
        let deposit = makeDeposit(principal: 20_000_000, sourceAccountID: wallet.id)
        let holding = makeHolding(
            units: 100,
            averageCostPerUnit: 50_000,
            currentNAVPerUnit: 60_000,
            sourceAccountID: wallet.id
        )
        let accounts = [wallet, card]
        let deposits = [deposit]
        let holdings = [holding]

        let slices = AssetAllocation.slices(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: []
        )
        let debt = AssetAllocation.debt(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: []
        )

        #expect(
            AssetAllocation.total(of: slices) - debt
                == AssetSummary.netWorth(
                    accounts: accounts,
                    deposits: deposits,
                    holdings: holdings,
                    transactions: []
                )
        )
    }

    @Test("Nothing overdrawn owes nothing")
    func noOverdraftMeansNoDebt() {
        let account = makeAccount(openingBalance: 10_000_000)

        #expect(
            AssetAllocation.debt(
                accounts: [account],
                deposits: [],
                holdings: [],
                transactions: []
            ) == 0
        )
    }

    @Test("Shares are rounded to one decimal place")
    func percentIsRounded() {
        #expect(AssetAllocation.percent(of: 25, in: 100) == 25)
        #expect(AssetAllocation.percent(of: 1, in: 3) == Decimal(string: "33.3"))
        #expect(AssetAllocation.percent(of: 2, in: 3) == Decimal(string: "66.7"))
    }

    @Test("An empty ring never divides by zero")
    func percentGuardsAgainstAnEmptyRing() {
        #expect(AssetAllocation.percent(of: 100, in: 0) == 0)
    }
}
