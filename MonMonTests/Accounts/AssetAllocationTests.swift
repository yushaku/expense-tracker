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
            kind: .normal,
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
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: fixedDate
        )
    }

    private func makeBorrowedDebt(principal: Decimal) -> Debt {
        Debt(
            id: UUID(),
            counterparty: "Anh Minh",
            direction: .borrowed,
            principal: principal,
            annualInterestRate: 0,
            openedAt: fixedDate,
            dueDate: nil,
            accountID: nil,
            note: "",
            currencyCode: VNDCurrency.code,
            createdAt: fixedDate
        )
    }

    @Test("Nothing held produces no wedges")
    func emptyPortfolioHasNoSlices() {
        let slices = AssetAllocation.slices(
            accounts: [],
            deposits: [],
            withdrawals: [],
            holdings: [],
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
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
            withdrawals: [],
            holdings: [holding],
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
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
            withdrawals: [],
            holdings: [],
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
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
            withdrawals: [],
            holdings: [],
            instruments: catalogue,
            transactions: transactions,
            transfers: [],
            debts: [],
            payments: [],
            sales: []
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
            withdrawals: [],
            holdings: [],
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
        )
        let overdraft = AssetAllocation.overdraft(
            accounts: [wallet, card],
            deposits: [],
            withdrawals: [],
            holdings: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
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
            withdrawals: [],
            holdings: holdings,
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
        )
        let liabilities = AssetAllocation.liabilities(
            accounts: accounts,
            deposits: deposits,
            withdrawals: [],
            holdings: holdings,
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
        )

        #expect(
            AssetAllocation.total(of: slices) - liabilities
                == AssetSummary.netWorth(
                    accounts: accounts,
                    deposits: deposits,
                    withdrawals: [],
                    holdings: holdings,
                    instruments: catalogue,
                    transactions: [],
                    transfers: [],
                    debts: [],
                    payments: [],
                    sales: []
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
            withdrawals: [],
            holdings: holdings,
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
        )

        #expect(slices.first { $0.kind == .funds }?.amount == 25_000_000)
        #expect(slices.first { $0.kind == .gold }?.amount == 147_000_000)
        #expect(
            AssetAllocation.total(of: slices)
                == AssetSummary.netWorth(
                    accounts: [account],
                    deposits: [],
                    withdrawals: [],
                    holdings: holdings,
                    instruments: catalogue,
                    transactions: [],
                    transfers: [],
                    debts: [],
                    payments: [],
                    sales: []
                )
        )
    }

    @Test("Crypto draws its own wedge and neither funds nor gold count it")
    func cryptoHasItsOwnWedge() {
        // Enough to have funded all three positions: cash is the opening
        // balance less what was spent on them, and an overdrawn account would
        // leave the ring instead of sitting in it.
        let account = makeAccount(openingBalance: 500_000_000)
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
        let coin = makeHolding(
            units: Decimal(string: "0.05") ?? 0,
            averageCostPerUnit: 1_800_000_000,
            pricePerUnit: 2_000_000_000,
            symbol: "BTC",
            kind: .crypto,
            sourceAccountID: account.id
        )
        let holdings = [fund, gold, coin]

        let slices = AssetAllocation.slices(
            accounts: [account],
            deposits: [],
            withdrawals: [],
            holdings: holdings,
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
        )

        #expect(slices.first { $0.kind == .funds }?.amount == 25_000_000)
        #expect(slices.first { $0.kind == .gold }?.amount == 147_000_000)
        #expect(slices.first { $0.kind == .crypto }?.amount == 100_000_000)
        #expect(
            AssetAllocation.total(of: slices)
                == AssetSummary.netWorth(
                    accounts: [account],
                    deposits: [],
                    withdrawals: [],
                    holdings: holdings,
                    instruments: catalogue,
                    transactions: [],
                    transfers: [],
                    debts: [],
                    payments: [],
                    sales: []
                )
        )
    }

    /// A fractional coin is the case the đồng-rounded arithmetic has to survive:
    /// the units carry eight decimal places and the value must not.
    @Test("A fraction of a coin is valued to the whole đồng")
    func fractionalCoinIsValuedWhole() {
        let account = makeAccount(openingBalance: 0)
        let coin = makeHolding(
            units: Decimal(string: "0.00000001") ?? 0,
            averageCostPerUnit: 1_800_000_000,
            pricePerUnit: 2_110_324_943,
            symbol: "BTC",
            kind: .crypto,
            sourceAccountID: account.id
        )

        let slices = AssetAllocation.slices(
            accounts: [account],
            deposits: [],
            withdrawals: [],
            holdings: [coin],
            instruments: catalogue,
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
        )

        // 0.00000001 × 2_110_324_943 = 21.10324943, rounded to the đồng.
        #expect(slices.first { $0.kind == .crypto }?.amount == 21)
    }

    @Test("Nothing overdrawn owes nothing")
    func noOverdraftOwesNothing() {
        let account = makeAccount(openingBalance: 10_000_000)

        #expect(
            AssetAllocation.overdraft(
                accounts: [account],
                deposits: [],
                withdrawals: [],
                holdings: [],
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == 0
        )
    }

    @Test("Liabilities are split into borrowed money and overdrafts")
    func liabilitiesAreSplitAndOrdered() {
        let account = makeAccount(openingBalance: -5_000_000)
        let debt = makeBorrowedDebt(principal: 20_000_000)

        let slices = AssetAllocation.liabilitySlices(
            accounts: [account],
            deposits: [],
            withdrawals: [],
            holdings: [],
            transactions: [],
            transfers: [],
            debts: [debt],
            payments: [],
            sales: []
        )

        #expect(slices.map(\.kind) == [.borrowed, .overdraft])
        #expect(slices.map(\.amount) == [20_000_000, 5_000_000])
        #expect(AssetAllocation.totalLiabilities(of: slices) == 25_000_000)
    }

    @Test("No amount owed produces no liability wedges")
    func noLiabilitiesHaveNoSlices() {
        let slices = AssetAllocation.liabilitySlices(
            accounts: [makeAccount(openingBalance: 10_000_000)],
            deposits: [],
            withdrawals: [],
            holdings: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: []
        )

        #expect(slices.isEmpty)
        #expect(AssetAllocation.totalLiabilities(of: slices) == 0)
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
