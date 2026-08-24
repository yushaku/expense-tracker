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
            kind: .bank,
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
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
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
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
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
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
            )
                == 8_900_000
        )
        #expect(
            CashBalanceSummary.totalAvailable(
                of: [account],
                deposits: deposits,
                holdings: [],
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
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
                holdings: [],
                instruments: catalogue,
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
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
                holdings: [],
                instruments: catalogue,
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
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
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
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
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
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
                holdings: [flat],
                instruments: catalogue,
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
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
                holdings: [gaining],
                instruments: catalogue,
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
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
                holdings: [external],
                instruments: catalogue,
                transactions: [],
                transfers: [],
                debts: [],
                payments: []
            )
                == 173_900_000
        )
    }

    @Test("Asset history samples the start, month ends, and current value")
    func assetHistorySamplesMonthlyValues() {
        let account = CashAccount(
            id: UUID(),
            name: "Wallet",
            kind: .cash,
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
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 3, 1)
        )
        let asOf = date(2024, 3, 15)

        let points = AssetHistory.points(
            accounts: [account],
            deposits: [],
            holdings: [],
            instruments: [],
            transactions: [income, expense],
            transfers: [],
            debts: [],
            payments: [],
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
            kind: .bank,
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
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
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
            kind: .bank,
            openingBalance: 100,
            currencyCode: VNDCurrency.code,
            createdAt: date(2024, 4, 1)
        )

        let points = AssetHistory.points(
            accounts: [futureAccount],
            deposits: [],
            holdings: [],
            instruments: [],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            asOf: date(2024, 3, 15),
            calendar: utcCalendar
        )

        #expect(points.isEmpty)
    }
}
