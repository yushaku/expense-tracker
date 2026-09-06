import Foundation
import Testing

@testable import MonMon

@Suite("Fund sale summary")
struct FundSaleSummaryTests {
    @Test("Sale fees reduce proceeds and realized PnL")
    func saleFeesReduceProceedsAndPnL() {
        let (_, holding) = FundTestFactory.pair(
            units: 10,
            averageCostPerUnit: 100,
            pricePerUnit: 150
        )
        let sale = FundTestFactory.sale(
            of: holding,
            units: 4,
            pricePerUnit: 150,
            fee: 50
        )

        #expect(FundSaleSummary.totalFees(of: [sale]) == 50)
        #expect(FundSaleSummary.totalProceeds(of: [sale]) == 550)
        #expect(FundSaleSummary.realizedProfitLoss(for: holding, sales: [sale]) == 150)
        #expect(holding.remainingCostBasis(sales: [sale]) == 600)
    }

    @Test("A group sale allocates one fee exactly across its lots")
    func groupSaleFeeAllocationIsExact() {
        let allocations = FundSaleSummary.allocateFee(300, grossProceeds: [1_000, 2_000])

        #expect(allocations == [100, 200])
        #expect(allocations.reduce(0, +) == 300)
    }

    @Test("Rounding never assigns a negative fee to any lot")
    func groupSaleFeeAllocationStaysNonnegative() {
        let allocations = FundSaleSummary.allocateFee(
            2,
            grossProceeds: [1_000, 1_000, 1_000, 1_000]
        )

        #expect(allocations.allSatisfy { $0 >= 0 })
        #expect(allocations.reduce(0, +) == 2)
    }

    /// The regression this exists for: the remainder used to land entirely on
    /// the last lot with positive weight. A dust lot standing last could be
    /// handed more fee than it sold for — a sale the editor refuses to write
    /// and the backup validator refuses to restore.
    @Test("No lot is charged more fee than it sold for")
    func noLotIsChargedBeyondItsProceeds() {
        let grossProceeds: [Decimal] = [100_000_000, 100_000_000, 100_000_000, 3]
        let allocations = FundSaleSummary.allocateFee(999, grossProceeds: grossProceeds)

        #expect(allocations.reduce(0, +) == 999)
        for (allocated, gross) in zip(allocations, grossProceeds) {
            #expect(allocated < gross, "a lot was charged \(allocated) against \(gross)")
        }
    }

    /// Flooring each share can only ever leave the total short, never over, so
    /// the shortfall has somewhere to go.
    @Test("Odd splits still add back to the fee that was typed")
    func oddSplitsAddBack() {
        let cases: [(fee: Decimal, gross: [Decimal])] = [
            (7, [3_000, 3_000, 3_000]),
            (1, [10, 10]),
            (99_999, [1_000_000, 333_333, 7]),
        ]

        for testCase in cases {
            let allocations = FundSaleSummary.allocateFee(
                testCase.fee,
                grossProceeds: testCase.gross
            )
            #expect(allocations.reduce(0, +) == testCase.fee)
            for (allocated, gross) in zip(allocations, testCase.gross) {
                #expect(allocated < gross)
            }
        }
    }

    /// A fee that eats the whole trade cannot be split so every part stays
    /// under its lot, and `FundSaleDraft` refuses it before this is reached.
    @Test("A fee at or above the whole trade allocates nothing")
    func feeCoveringEverythingAllocatesNothing() {
        #expect(FundSaleSummary.allocateFee(3_000, grossProceeds: [1_000, 2_000]) == [0, 0])
        #expect(FundSaleSummary.allocateFee(4_000, grossProceeds: [1_000, 2_000]) == [0, 0])
    }

    @Test("A closed lot carries none of the fee")
    func closedLotCarriesNoFee() {
        #expect(
            FundSaleSummary.allocateFee(300, grossProceeds: [1_000, 0, 2_000]) == [100, 0, 200]
        )
    }

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
            kind: .normal,
            openingBalance: 0,
            currencyCode: VNDCurrency.code,
            createdAt: FundTestFactory.referenceDate
        )
        let elsewhere = CashAccount(
            id: UUID(),
            name: "Cash",
            kind: .normal,
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
