import Foundation
import Testing

@testable import MonMon

@Suite("Fund sale summary")
struct FundSaleSummaryTests {
    @Test("A lot nobody has sold out of is fully held")
    func untouchedLotIsFullyHeld() {
        let (_, holding) = FundTestFactory.pair(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )

        #expect(FundSaleSummary.unitsSold(for: holding, sales: []) == 0)
        #expect(FundSaleSummary.remainingUnits(of: holding, sales: []) == 1_000)
        #expect(FundSaleSummary.isClosed(holding, sales: []) == false)
        #expect(FundSaleSummary.realizedProfitLoss(for: holding, sales: []) == 0)
    }

    @Test("Selling part of a lot leaves the rest held and banks the profit on what went")
    func partialSaleLeavesTheRest() {
        let (_, holding) = FundTestFactory.pair(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )
        let sales = [FundTestFactory.sale(of: holding, units: 400, pricePerUnit: 26_000)]

        #expect(FundSaleSummary.remainingUnits(of: holding, sales: sales) == 600)
        #expect(FundSaleSummary.isClosed(holding, sales: sales) == false)
        // 400 × (26.000 − 20.000)
        #expect(FundSaleSummary.realizedProfitLoss(for: holding, sales: sales) == 2_400_000)
        #expect(FundSaleSummary.totalProceeds(of: sales) == 10_400_000)
    }

    @Test("Selling the rest closes the lot, and the loss it took stands")
    func sellingTheRestClosesTheLot() {
        let (_, holding) = FundTestFactory.pair(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )
        let sales = [
            FundTestFactory.sale(of: holding, units: 400, pricePerUnit: 26_000),
            FundTestFactory.sale(of: holding, units: 600, pricePerUnit: 18_000),
        ]

        #expect(FundSaleSummary.remainingUnits(of: holding, sales: sales) == 0)
        #expect(FundSaleSummary.isClosed(holding, sales: sales))
        // +2.400.000 on the first, −1.200.000 on the second.
        #expect(FundSaleSummary.realizedProfitLoss(for: holding, sales: sales) == 1_200_000)
    }

    @Test("A sale out of another lot never touches this one")
    func salesStayWithTheirOwnLot() {
        let (fund, holding) = FundTestFactory.pair(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )
        let other = FundTestFactory.holding(in: fund, units: 500, averageCostPerUnit: 21_000)
        let sales = [FundTestFactory.sale(of: other, units: 500, pricePerUnit: 26_000)]

        #expect(FundSaleSummary.remainingUnits(of: holding, sales: sales) == 1_000)
        #expect(FundSaleSummary.realizedProfitLoss(for: holding, sales: sales) == 0)
        #expect(FundSaleSummary.remainingUnits(of: other, sales: sales) == 0)
    }

    @Test("Overselling a lot is reported, not clamped away")
    func oversellingShowsAsNegative() {
        let (_, holding) = FundTestFactory.pair(
            units: 100,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )
        let sales = [FundTestFactory.sale(of: holding, units: 150, pricePerUnit: 26_000)]

        #expect(FundSaleSummary.remainingUnits(of: holding, sales: sales) == -50)
        #expect(FundSaleSummary.isClosed(holding, sales: sales))
    }

    @Test("A sale naming a lot nobody holds makes no profit at all")
    func orphanSaleRealizesNothing() {
        let (_, holding) = FundTestFactory.pair(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )
        let sale = FundTestFactory.sale(of: holding, units: 400, pricePerUnit: 26_000)

        #expect(FundSaleSummary.totalRealizedProfitLoss(of: [sale], holdings: []) == 0)
        #expect(
            FundSaleSummary.totalRealizedProfitLoss(of: [sale], holdings: [holding])
                == 2_400_000
        )
    }

    @Test("Proceeds reach the account the sale names and no other")
    func proceedsReachOneAccount() {
        let account = CashAccount(
            id: UUID(),
            name: "Techcombank",
            kind: .bank,
            openingBalance: 0,
            currencyCode: VNDCurrency.code,
            createdAt: FundTestFactory.referenceDate
        )
        let elsewhere = CashAccount(
            id: UUID(),
            name: "Cash",
            kind: .cash,
            openingBalance: 0,
            currencyCode: VNDCurrency.code,
            createdAt: FundTestFactory.referenceDate
        )
        let (_, holding) = FundTestFactory.pair(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )
        let sales = [
            FundTestFactory.sale(
                of: holding,
                units: 400,
                pricePerUnit: 26_000,
                proceedsAccountID: account.id
            )
        ]

        #expect(FundSaleSummary.netFlow(for: account, sales: sales) == 10_400_000)
        #expect(FundSaleSummary.netFlow(for: elsewhere, sales: sales) == 0)
        #expect(FundSaleSummary.count(for: account, sales: sales) == 1)
        #expect(FundSaleSummary.count(for: elsewhere, sales: sales) == 0)
    }

    @Test("A fund's sales gather every lot held in it, newest first")
    func salesGatherByInstrument() {
        let (fund, first) = FundTestFactory.pair(
            units: 1_000,
            averageCostPerUnit: 20_000,
            pricePerUnit: 25_000
        )
        let second = FundTestFactory.holding(in: fund, units: 500, averageCostPerUnit: 21_000)
        let gold = FundTestFactory.instrument(
            symbol: "SJC",
            kind: .gold,
            pricePerUnit: 80_000_000
        )
        let bar = FundTestFactory.holding(in: gold, units: 1, averageCostPerUnit: 75_000_000)

        let older = FundTestFactory.sale(
            of: first,
            units: 100,
            pricePerUnit: 26_000,
            soldAt: FundTestFactory.referenceDate
        )
        let newer = FundTestFactory.sale(
            of: second,
            units: 100,
            pricePerUnit: 27_000,
            soldAt: FundTestFactory.referenceDate.addingTimeInterval(86_400)
        )
        let unrelated = FundTestFactory.sale(of: bar, units: 1, pricePerUnit: 80_000_000)

        let gathered = FundSaleSummary.sales(
            forInstrumentID: fund.id,
            holdings: [first, second, bar],
            sales: [older, newer, unrelated]
        )

        #expect(gathered.map(\.id) == [newer.id, older.id])
    }
}
