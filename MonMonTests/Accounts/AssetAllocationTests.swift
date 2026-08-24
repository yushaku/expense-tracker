import Foundation
import Testing

@testable import MonMon

@Suite("Asset allocation")
final class AssetAllocationTests {
    /// Every instrument `makeHolding` minted, in the order it was asked for.
    private var catalogue: [FundInstrument] = []

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

    /// A position and the catalogue entry that prices it, kept together because
    /// one without the other cannot be valued since the split.
    private func makeHolding(
        units: Decimal,
        averageCostPerUnit: Decimal,
        pricePerUnit: Decimal,
        symbol: String = "VESAF",
        kind: FundInstrumentKind = .fund,
        sourceAccountID: UUID? = nil
    ) -> FundHolding {
        let instrument = FundTestFactory.instrument(
            symbol: symbol,
            kind: kind,
            pricePerUnit: pricePerUnit
        )
        catalogue.append(instrument)

        return FundTestFactory.holding(
            in: instrument,
            units: units,
            averageCostPerUnit: averageCostPerUnit,
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
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: []
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
            pricePerUnit: 25_000,
            sourceAccountID: account.id
        )

        let slices = AssetAllocation.slices(
            accounts: [account],
            deposits: [deposit],
            holdings: [holding],
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: []
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
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: []
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
            instruments: catalogue,
            transactions: transactions,
            transfers: [],
            debts: [],
            payments: []
        )

        #expect(slices.first?.amount == 9_800_000)
    }

    @Test("An overdrawn account leaves the ring and is reported as an overdraft")
    func overdrawnAccountBecomesAnOverdraft() {
        let wallet = makeAccount(openingBalance: 10_000_000)
        let card = makeAccount(openingBalance: -5_200_000)

        let slices = AssetAllocation.slices(
            accounts: [wallet, card],
            deposits: [],
            holdings: [],
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: []
        )
        let overdraft = AssetAllocation.overdraft(
            accounts: [wallet, card],
            deposits: [],
            holdings: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: []
        )

        // The ring shows only what is held; the card is not netted off it.
        #expect(slices.map(\.amount) == [10_000_000])
        #expect(overdraft == 5_200_000)
    }

    @Test("The ring total minus what is owed equals net worth")
    func ringMinusLiabilitiesIsNetWorth() {
        let wallet = makeAccount(openingBalance: 60_000_000)
        let card = makeAccount(openingBalance: -5_000_000)
        let deposit = makeDeposit(principal: 20_000_000, sourceAccountID: wallet.id)
        let holding = makeHolding(
            units: 100,
            averageCostPerUnit: 50_000,
            pricePerUnit: 60_000,
            sourceAccountID: wallet.id
        )
        let accounts = [wallet, card]
        let deposits = [deposit]
        let holdings = [holding]

        let slices = AssetAllocation.slices(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: []
        )
        let liabilities = AssetAllocation.liabilities(
            accounts: accounts,
            deposits: deposits,
            holdings: holdings,
            transactions: [],
            transfers: [],
            debts: [],
            payments: []
        )

        #expect(
            AssetAllocation.total(of: slices) - liabilities
                == AssetSummary.netWorth(
                    accounts: accounts,
                    deposits: deposits,
                    holdings: holdings,
                    instruments: catalogue,
                    transactions: [],
                    transfers: [],
                    debts: [],
                    payments: []
                )
        )
    }

    @Test("Gold draws its own wedge and funds no longer count it")
    func goldHasItsOwnWedge() {
        let account = makeAccount(openingBalance: 200_000_000)
        let fund = makeHolding(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000,
            sourceAccountID: account.id
        )
        let gold = makeHolding(
            units: 1,
            averageCostPerUnit: 140_000_000,
            pricePerUnit: 147_000_000,
            symbol: "SJL1L10",
            kind: .gold,
            sourceAccountID: account.id
        )
        let holdings = [fund, gold]

        let slices = AssetAllocation.slices(
            accounts: [account],
            deposits: [],
            holdings: holdings,
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: []
        )

        #expect(slices.first { $0.kind == .funds }?.amount == 25_000_000)
        #expect(slices.first { $0.kind == .gold }?.amount == 147_000_000)
        #expect(
            AssetAllocation.total(of: slices)
                == AssetSummary.netWorth(
                    accounts: [account],
                    deposits: [],
                    holdings: holdings,
                    instruments: catalogue,
                    transactions: [],
                    transfers: [],
                    debts: [],
                    payments: []
                )
        )
    }

    @Test("Nothing overdrawn owes nothing")
    func noOverdraftOwesNothing() {
        let account = makeAccount(openingBalance: 10_000_000)

        #expect(
            AssetAllocation.overdraft(
                accounts: [account],
                deposits: [],
                holdings: [],
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
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
