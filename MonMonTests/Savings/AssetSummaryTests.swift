import Foundation
import Testing

@testable import MonMon

@Suite("Asset summary")
final class AssetSummaryTests {
    /// Every instrument `makeHolding` minted, in the order it was asked for.
    private var catalogue: [FundInstrument] = []

    private let openedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeAccount(openingBalance: Decimal) -> CashAccount {
        CashAccount(
            id: UUID(),
            name: "Techcombank",
            kind: .normal,
            openingBalance: openingBalance,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt
        )
    }

    /// A position and the catalogue entry that prices it. Since the split, one
    /// without the other cannot be valued, so the pair is built together and the
    /// instrument is kept on the holding for the assertions below.
    private func makeHolding(
        units: Decimal,
        averageCostPerUnit: Decimal,
        pricePerUnit: Decimal,
        symbol: String = "VESAF",
        sourceAccountID: UUID? = nil
    ) -> FundHolding {
        let instrument = FundTestFactory.instrument(
            symbol: symbol,
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

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        utcCalendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        ) ?? Date(timeIntervalSince1970: 0)
    }

    @Test("No deposits total to zero")
    func emptyDepositsTotalZero() {
        #expect(AssetSummary.totalPrincipal(of: [], withdrawals: []) == 0)
        #expect(AssetSummary.totalProjectedInterest(of: [], withdrawals: []) == 0)
        #expect(AssetSummary.totalMaturityValue(of: [], withdrawals: []) == 0)
    }

    @Test("Multiple deposit principals add exactly")
    func principalsAddExactly() {
        let deposits = [
            makeDeposit(principal: 100_000_000),
            makeDeposit(principal: 250_000_000),
            makeDeposit(principal: 1_500_000),
        ]

        #expect(AssetSummary.totalPrincipal(of: deposits, withdrawals: []) == 351_500_000)
    }

    @Test("Projected interest sums each deposit's own term")
    func projectedInterestSums() {
        let deposits = [
            makeDeposit(principal: 100_000_000, rate: 6, termMonths: 12),
            makeDeposit(principal: 200_000_000, rate: 6, termMonths: 12),
        ]
        let expected = deposits.reduce(Decimal.zero) { $0 + $1.projectedInterest }

        #expect(AssetSummary.totalProjectedInterest(of: deposits, withdrawals: []) == expected)
        #expect(expected > 0)
    }

    @Test("An unfunded account keeps its full opening balance available")
    func unfundedAccountIsFullyAvailable() {
        let account = makeAccount(openingBalance: 148_900_000)
        let unrelated = makeDeposit(principal: 100_000_000, sourceAccountID: UUID())

        #expect(
            CashBalanceSummary.fundedAmount(
                for: account,
                deposits: [unrelated],
                holdings: []
            ) == 0
        )
        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [unrelated],
                holdings: [],
                withdrawals: [],
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            )
                == 148_900_000
        )
    }

    @Test("A funded account reports the deposited principal as unavailable")
    func fundedAccountReducesAvailableBalance() {
        let account = makeAccount(openingBalance: 148_900_000)
        let deposit = makeDeposit(principal: 100_000_000, sourceAccountID: account.id)

        #expect(
            CashBalanceSummary.fundedAmount(for: account, deposits: [deposit], holdings: [])
                == 100_000_000
        )
        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [deposit],
                holdings: [],
                withdrawals: [],
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            )
                == 48_900_000
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
            CashBalanceSummary.available(
                for: account,
                deposits: deposits,
                holdings: [],
                withdrawals: [],
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            )
                == 8_900_000
        )
        #expect(
            CashBalanceSummary.totalAvailable(
                of: [account],
                deposits: deposits,
                holdings: [],
                withdrawals: [],
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == 8_900_000
        )
    }

    @Test("Net worth counts money moved into a deposit exactly once")
    func netWorthDoesNotDoubleCount() {
        let account = makeAccount(openingBalance: 148_900_000)
        let funded = makeDeposit(principal: 100_000_000, sourceAccountID: account.id)

        #expect(
            AssetSummary.netWorth(
                accounts: [account],
                deposits: [funded],
                withdrawals: [],
                holdings: [],
                instruments: catalogue,
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            )
                == 148_900_000
        )
    }

    @Test("A deposit without a source account adds to net worth")
    func unfundedDepositAddsToNetWorth() {
        let account = makeAccount(openingBalance: 148_900_000)
        let external = makeDeposit(principal: 250_000_000)

        #expect(
            AssetSummary.netWorth(
                accounts: [account],
                deposits: [external],
                withdrawals: [],
                holdings: [],
                instruments: catalogue,
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            )
                == 398_900_000
        )
    }

    @Test("A funded holding removes its cost basis from the available balance")
    func fundedHoldingReducesAvailableBalance() {
        let account = makeAccount(openingBalance: 148_900_000)
        let holding = makeHolding(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000,
            sourceAccountID: account.id
        )

        #expect(
            CashBalanceSummary.fundedAmount(for: account, deposits: [], holdings: [holding])
                == 20_000_000
        )
        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: [holding],
                withdrawals: [],
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            )
                == 128_900_000
        )
    }

    @Test("One account funding both a deposit and a holding loses both amounts")
    func depositAndHoldingBothReduceAvailableBalance() {
        let account = makeAccount(openingBalance: 148_900_000)
        let deposit = makeDeposit(principal: 100_000_000, sourceAccountID: account.id)
        let holding = makeHolding(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000,
            sourceAccountID: account.id
        )

        #expect(
            CashBalanceSummary.available(
                for: account,
                deposits: [deposit],
                holdings: [holding],
                withdrawals: [],
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            ) == 28_900_000
        )
    }

    @Test("Net worth counts a funded holding's cost exactly once and adds its gain")
    func netWorthCountsHoldingCostOnceAndAddsGain() {
        let account = makeAccount(openingBalance: 148_900_000)
        let flat = makeHolding(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 20_000,
            sourceAccountID: account.id
        )

        // NAV still equals the average cost, so buying moved money without
        // changing what it is all worth.
        #expect(
            AssetSummary.netWorth(
                accounts: [account],
                deposits: [],
                withdrawals: [],
                holdings: [flat],
                instruments: catalogue,
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            )
                == 148_900_000
        )

        let gaining = makeHolding(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000,
            sourceAccountID: account.id
        )

        // The NAV is 5.000 ₫ higher on 1.000 units, so net worth grows by exactly
        // the 5.000.000 ₫ unrealized gain.
        #expect(
            AssetSummary.netWorth(
                accounts: [account],
                deposits: [],
                withdrawals: [],
                holdings: [gaining],
                instruments: catalogue,
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            )
                == 153_900_000
        )
    }

    @Test("An unfunded holding adds its whole market value to net worth")
    func unfundedHoldingAddsMarketValue() {
        let account = makeAccount(openingBalance: 148_900_000)
        let external = makeHolding(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )

        #expect(
            AssetSummary.netWorth(
                accounts: [account],
                deposits: [],
                withdrawals: [],
                holdings: [external],
                instruments: catalogue,
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: []
            )
                == 173_900_000
        )
    }

    @Test("Asset history samples the start, month ends, and current value")
    func assetHistorySamplesMonthlyValues() {
        let account = CashAccount(
            id: UUID(),
            name: "Wallet",
            kind: .normal,
            openingBalance: 100,
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 1, 10)
        )
        let income = MoneyTransaction(
            id: UUID(),
            kind: .income,
            amount: 25,
            occurredAt: date(2024, 2, 10),
            note: "",
            accountID: account.id,
            categoryID: nil,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 2, 10)
        )
        let expense = MoneyTransaction(
            id: UUID(),
            kind: .expense,
            amount: 5,
            occurredAt: date(2024, 3, 1),
            note: "",
            accountID: account.id,
            categoryID: nil,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 3, 1)
        )
        let asOf = date(2024, 3, 15)

        let points = AssetHistory.points(
            accounts: [account],
            deposits: [],
            withdrawals: [],
            holdings: [],
            instruments: [],
            transactions: [income, expense],
            transfers: [],
            debts: [],
            payments: [],
            sales: [],
            asOf: asOf,
            calendar: utcCalendar
        )

        #expect(points.map(\.netWorth) == [100, 100, 125, 120])
        #expect(points.first?.date == account.createdAt)
        #expect(points.last?.date == asOf)
    }

    @Test("Moving cash into savings does not create artificial growth")
    func assetHistoryKeepsFundedSavingsNeutral() {
        let account = CashAccount(
            id: UUID(),
            name: "Bank",
            kind: .normal,
            openingBalance: 100,
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 1, 10)
        )
        let deposit = SavingsDeposit(
            id: UUID(),
            name: "Deposit",
            principal: 40,
            annualInterestRate: 5,
            termMonths: 12,
            openedAt: date(2024, 2, 10),
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 2, 10),
            sourceAccountID: account.id
        )

        let points = AssetHistory.points(
            accounts: [account],
            deposits: [deposit],
            withdrawals: [],
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: [],
            asOf: date(2024, 3, 15),
            calendar: utcCalendar
        )

        #expect(points.map(\.netWorth) == [100, 100, 100, 100])
    }

    @Test("Asset history ignores records after the requested date")
    func assetHistoryIgnoresFutureRecords() {
        let futureAccount = CashAccount(
            id: UUID(),
            name: "Future",
            kind: .normal,
            openingBalance: 100,
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 4, 1)
        )

        let points = AssetHistory.points(
            accounts: [futureAccount],
            deposits: [],
            withdrawals: [],
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: [],
            asOf: date(2024, 3, 15),
            calendar: utcCalendar
        )

        #expect(points.isEmpty)
    }

    @Test("A point splits into the same groups the ring draws, zeros kept")
    func assetHistoryPointCarriesItsComposition() {
        let account = CashAccount(
            id: UUID(),
            name: "Bank",
            kind: .normal,
            openingBalance: 100,
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 1, 10)
        )
        let deposit = SavingsDeposit(
            id: UUID(),
            name: "Deposit",
            principal: 40,
            annualInterestRate: 5,
            termMonths: 12,
            openedAt: date(2024, 2, 10),
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 2, 10),
            sourceAccountID: account.id
        )

        let points = AssetHistory.points(
            accounts: [account],
            deposits: [deposit],
            withdrawals: [],
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: [],
            asOf: date(2024, 3, 15),
            calendar: utcCalendar
        )

        let opening = try! #require(points.first)
        let latest = try! #require(points.last)

        // Every group is present on every point, in one order, so a chart of
        // them never swaps a band between months.
        #expect(opening.composition.map(\.kind) == AssetAllocationSlice.Kind.allCases)
        #expect(latest.composition.map(\.kind) == AssetAllocationSlice.Kind.allCases)

        #expect(amount(of: .cash, in: opening) == 100)
        #expect(amount(of: .savings, in: opening) == 0)

        // Funding the book moved the money without making any.
        #expect(amount(of: .cash, in: latest) == 60)
        #expect(amount(of: .savings, in: latest) == 40)
        #expect(latest.netWorth == 100)
    }

    @Test("What is owed is the gap between the bands and the line")
    func assetHistoryCompositionExcludesWhatIsOwed() {
        let account = CashAccount(
            id: UUID(),
            name: "Bank",
            kind: .normal,
            openingBalance: 100,
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 1, 10)
        )
        let borrowed = Debt(
            id: UUID(),
            counterparty: "Bank",
            direction: .borrowed,
            principal: 30,
            annualInterestRate: 0,
            openedAt: date(2024, 1, 10),
            dueDate: nil,
            accountID: nil,
            note: "",
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 1, 10)
        )

        let points = AssetHistory.points(
            accounts: [account],
            deposits: [],
            withdrawals: [],
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: [],
            debts: [borrowed],
            payments: [],
            sales: [],
            asOf: date(2024, 2, 15),
            calendar: utcCalendar
        )

        let latest = try! #require(points.last)
        let banded = latest.composition.reduce(Decimal.zero) { $0 + $1.amount }

        #expect(banded == 100)
        #expect(latest.netWorth == 70)
    }

    private func amount(
        of kind: AssetAllocationSlice.Kind,
        in point: AssetHistoryPoint
    ) -> Decimal {
        point.composition.first { $0.kind == kind }?.amount ?? .zero
    }
}
