import Foundation
import Testing

@testable import MonMon

/// Closing a position must not move net worth on the day it is closed.
///
/// This is the one invariant the whole design rests on. A lot keeps its original
/// cost subtracted from the spendable side forever, and a sale adds its proceeds
/// back; if either half were also to shrink the lot, the same đồng would be
/// counted twice and net worth would jump for no reason the owner could see.
@Suite("Selling and net worth")
struct FundSaleNetWorthTests {
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

    private func netWorth(
        account: CashAccount,
        holdings: [FundHolding],
        instruments: [FundInstrument],
        sales: [FundSale]
    ) -> Decimal {
        AssetSummary.netWorth(
            accounts: [account],
            deposits: [],
            withdrawals: [],
            holdings: holdings,
            instruments: instruments,
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: sales
        )
    }

    @Test("Selling at today's price leaves net worth exactly where it was")
    func sellingAtMarketLeavesNetWorthAlone() {
        let account = makeAccount(openingBalance: 50_000_000)
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000,
            sourceAccountID: account.id
        )

        let before = netWorth(
            account: account,
            holdings: [holding],
            instruments: [instrument],
            sales: []
        )

        let sale = FundTestFactory.sale(
            of: holding,
            units: 1_000,
            pricePerUnit: 25_000,
            proceedsAccountID: account.id
        )

        let after = netWorth(
            account: account,
            holdings: [holding],
            instruments: [instrument],
            sales: [sale]
        )

        // 50.000.000 opening − 20.000.000 cost + 25.000.000 market value.
        #expect(before == 55_000_000)
        #expect(after == before)
    }

    @Test("Selling half leaves net worth alone too")
    func sellingHalfLeavesNetWorthAlone() {
        let account = makeAccount(openingBalance: 50_000_000)
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000,
            sourceAccountID: account.id
        )
        let sale = FundTestFactory.sale(
            of: holding,
            units: 500,
            pricePerUnit: 25_000,
            proceedsAccountID: account.id
        )

        #expect(
            netWorth(
                account: account,
                holdings: [holding],
                instruments: [instrument],
                sales: [sale]
            ) == 55_000_000
        )
    }

    @Test("Selling above the market raises net worth by exactly the extra")
    func sellingAboveMarketRaisesNetWorth() {
        let account = makeAccount(openingBalance: 50_000_000)
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000,
            sourceAccountID: account.id
        )
        let sale = FundTestFactory.sale(
            of: holding,
            units: 1_000,
            pricePerUnit: 26_000,
            proceedsAccountID: account.id
        )

        #expect(
            netWorth(
                account: account,
                holdings: [holding],
                instruments: [instrument],
                sales: [sale]
            ) == 56_000_000
        )
    }

    @Test("The proceeds land in the account the sale names, not the one that funded it")
    func proceedsLandWhereTheSaleSays() {
        let funding = makeAccount(openingBalance: 50_000_000)
        let wallet = CashAccount(
            id: UUID(),
            name: "Wallet",
            kind: .cash,
            openingBalance: 0,
            currencyCode: VNDCurrency.code,
            createdAt: openedAt
        )
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000,
            sourceAccountID: funding.id
        )
        let sale = FundTestFactory.sale(
            of: holding,
            units: 1_000,
            pricePerUnit: 26_000,
            proceedsAccountID: wallet.id
        )

        let available = { (account: CashAccount) in
            CashBalanceSummary.available(
                for: account,
                deposits: [],
                holdings: [holding],
                withdrawals: [],
                transactions: [],
                transfers: [],
                debts: [],
                payments: [],
                sales: [sale]
            )
        }

        // The funding account is still down the original cost; the money came
        // back somewhere else, which is exactly what the owner said happened.
        #expect(available(funding) == 30_000_000)
        #expect(available(wallet) == 26_000_000)
    }

    @Test("A closed position stops counting as an investment")
    func closedPositionLeavesTheInvestmentsTotal() {
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundTestFactory.holding(
            in: instrument,
            units: 1_000,
            averageCostPerUnit: 20_000
        )
        let sale = FundTestFactory.sale(of: holding, units: 1_000, pricePerUnit: 26_000)

        #expect(
            InvestmentSummary.total(
                deposits: [],
                withdrawals: [],
                holdings: [holding],
                instruments: [instrument],
                sales: []
            ) == 25_000_000
        )
        #expect(
            InvestmentSummary.total(
                deposits: [],
                withdrawals: [],
                holdings: [holding],
                instruments: [instrument],
                sales: [sale]
            ) == 0
        )
    }

    @Test("A month that ended before the sale still shows the position held")
    func historyBeforeASaleStillHoldsIt() {
        let calendar: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
            return calendar
        }()

        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
        }

        let account = CashAccount(
            id: UUID(),
            name: "Techcombank",
            kind: .bank,
            openingBalance: 50_000_000,
            currencyCode: VNDCurrency.code,
            createdAt: date(2026, 1, 1)
        )
        let instrument = FundTestFactory.instrument(pricePerUnit: 25_000)
        let holding = FundHolding(
            id: UUID(),
            instrumentID: instrument.id,
            units: 1_000,
            averageCostPerUnit: 20_000,
            createdAt: date(2026, 1, 1),
            sourceAccountID: account.id,
            purchasedAt: date(2026, 1, 1)
        )
        let sale = FundSale(
            id: UUID(),
            holdingID: holding.id,
            units: 1_000,
            pricePerUnit: 30_000,
            proceedsAccountID: account.id,
            soldAt: date(2026, 3, 10),
            createdAt: date(2026, 3, 10)
        )

        let points = AssetHistory.points(
            accounts: [account],
            deposits: [],
            withdrawals: [],
            holdings: [holding],
            instruments: [instrument],
            transactions: [],
            transfers: [],
            debts: [],
            payments: [],
            sales: [sale],
            asOf: date(2026, 3, 31),
            calendar: calendar
        )

        // January and February end with the position still open, valued at
        // today's price; March ends with it sold at more than that.
        #expect(points.map(\.netWorth) == [55_000_000, 55_000_000, 55_000_000, 60_000_000])
    }
}
