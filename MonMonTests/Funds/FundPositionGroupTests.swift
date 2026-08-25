import Foundation
import Testing

@testable import MonMon

@Suite("Fund position groups")
struct FundPositionGroupTests {
    @Test("Positions in the same fund land in one group")
    func samefundGroupsTogether() {
        let vesaf = FundTestFactory.instrument(symbol: "VESAF", pricePerUnit: 30_000)
        let dcds = FundTestFactory.instrument(symbol: "DCDS", pricePerUnit: 90_000)

        let groups = FundSummary.groups(
            holdings: [
                FundTestFactory.holding(in: vesaf, units: 100, averageCostPerUnit: 20_000),
                FundTestFactory.holding(in: vesaf, units: 100, averageCostPerUnit: 24_000),
                FundTestFactory.holding(in: dcds, units: 10, averageCostPerUnit: 80_000),
            ],
            instruments: [vesaf, dcds],
            sales: []
        )

        #expect(groups.count == 2)
        #expect(groups.map(\.symbol) == ["VESAF", "DCDS"])
        #expect(groups.first?.holdings.count == 2)
    }

    /// The figure a DCA buyer reads: what the whole stack cost per unit, not the
    /// average of the two prices paid.
    @Test("Average cost is weighted by what each purchase bought")
    func averageCostIsWeighted() {
        let vesaf = FundTestFactory.instrument(pricePerUnit: 30_000)
        let group = FundPositionGroup(
            instrument: vesaf,
            instrumentID: vesaf.id,
            holdings: [
                FundTestFactory.holding(in: vesaf, units: 300, averageCostPerUnit: 20_000),
                FundTestFactory.holding(in: vesaf, units: 100, averageCostPerUnit: 28_000),
            ],
            sales: []
        )

        #expect(group.units == 400)
        #expect(group.costBasis == 8_800_000)
        // 8,800,000 / 400 — not the 24,000 an unweighted mean would give.
        #expect(group.averageCostPerUnit == 22_000)
    }

    @Test("The group values and totals the whole stack")
    func groupValuesTheStack() {
        let vesaf = FundTestFactory.instrument(pricePerUnit: 25_000)
        let group = FundPositionGroup(
            instrument: vesaf,
            instrumentID: vesaf.id,
            holdings: [
                FundTestFactory.holding(in: vesaf, units: 500, averageCostPerUnit: 20_000),
                FundTestFactory.holding(in: vesaf, units: 500, averageCostPerUnit: 20_000),
            ],
            sales: []
        )

        #expect(group.marketValue == 25_000_000)
        #expect(group.unrealizedProfitLoss == 5_000_000)
        #expect(group.returnPercent == 25)
        #expect(group.isGain)
    }

    @Test("A position with no instrument groups on its own and is worth nothing")
    func unmatchedPositionsGroupApart() {
        let vesaf = FundTestFactory.instrument(pricePerUnit: 30_000)
        let orphan = FundHolding(
            id: UUID(),
            instrumentID: nil,
            units: 10,
            averageCostPerUnit: 50_000,
            createdAt: FundTestFactory.referenceDate
        )

        let groups = FundSummary.groups(
            holdings: [
                FundTestFactory.holding(in: vesaf, units: 100, averageCostPerUnit: 20_000),
                orphan,
            ],
            instruments: [vesaf],
            sales: []
        )

        #expect(groups.count == 2)
        // Worth nothing the app can prove, so it sorts last rather than leading.
        #expect(groups.last?.instrument == nil)
        #expect(groups.last?.marketValue == 0)
        #expect(groups.last?.costBasis == 500_000)
        #expect(groups.last?.id == "unmatched")
    }

    @Test("A group with no cost basis reports no return rather than dividing by zero")
    func zeroCostBasisIsSafe() {
        let vesaf = FundTestFactory.instrument(pricePerUnit: 30_000)
        let group = FundPositionGroup(
            instrument: vesaf,
            instrumentID: vesaf.id,
            holdings: [FundTestFactory.holding(in: vesaf, units: 0, averageCostPerUnit: 0)],
            sales: []
        )

        #expect(group.averageCostPerUnit == 0)
        #expect(group.returnPercent == 0)
    }

    @Test("Positions of one instrument come back newest first")
    func positionsAreNewestFirst() {
        let vesaf = FundTestFactory.instrument(pricePerUnit: 30_000)
        let older = FundTestFactory.holding(
            in: vesaf,
            units: 100,
            averageCostPerUnit: 20_000,
            createdAt: FundTestFactory.referenceDate
        )
        let newer = FundTestFactory.holding(
            in: vesaf,
            units: 100,
            averageCostPerUnit: 24_000,
            createdAt: FundTestFactory.referenceDate.addingTimeInterval(86_400)
        )

        let positions = FundSummary.positions(
            forInstrumentID: vesaf.id,
            holdings: [older, newer]
        )

        #expect(positions.map(\.id) == [newer.id, older.id])
    }

    @Test("A part-sold stack counts only what is left, and banks what went")
    func partSoldStackCountsWhatIsLeft() {
        let vesaf = FundTestFactory.instrument(pricePerUnit: 30_000)
        let first = FundTestFactory.holding(in: vesaf, units: 300, averageCostPerUnit: 20_000)
        let second = FundTestFactory.holding(in: vesaf, units: 100, averageCostPerUnit: 28_000)
        let sales = [FundTestFactory.sale(of: first, units: 100, pricePerUnit: 32_000)]
        let group = FundPositionGroup(
            instrument: vesaf,
            instrumentID: vesaf.id,
            holdings: [first, second],
            sales: sales
        )

        #expect(group.units == 300)
        // 200 × 20.000 still in the first lot, 100 × 28.000 in the second.
        #expect(group.costBasis == 6_800_000)
        // The whole outlay stands, because that is what left the accounts.
        #expect(group.investedCostBasis == 8_800_000)
        #expect(group.marketValue == 9_000_000)
        #expect(group.unrealizedProfitLoss == 2_200_000)
        // 100 × (32.000 − 20.000)
        #expect(group.realizedProfitLoss == 1_200_000)
        #expect(group.proceeds == 3_200_000)
        #expect(group.isFullyClosed == false)
        #expect(group.openHoldings.count == 2)
    }

    @Test("A stack sold out of entirely is closed, and only its realized figure stands")
    func fullySoldStackIsClosed() {
        let vesaf = FundTestFactory.instrument(pricePerUnit: 30_000)
        let first = FundTestFactory.holding(in: vesaf, units: 300, averageCostPerUnit: 20_000)
        let second = FundTestFactory.holding(in: vesaf, units: 100, averageCostPerUnit: 28_000)
        let sales = [
            FundTestFactory.sale(of: first, units: 300, pricePerUnit: 32_000),
            FundTestFactory.sale(of: second, units: 100, pricePerUnit: 32_000),
        ]
        let group = FundPositionGroup(
            instrument: vesaf,
            instrumentID: vesaf.id,
            holdings: [first, second],
            sales: sales
        )

        #expect(group.units == 0)
        #expect(group.costBasis == 0)
        #expect(group.marketValue == 0)
        #expect(group.unrealizedProfitLoss == 0)
        #expect(group.returnPercent == 0)
        // 300 × 12.000 + 100 × 4.000
        #expect(group.realizedProfitLoss == 4_000_000)
        #expect(group.isFullyClosed)
        #expect(group.openHoldings.isEmpty)
    }

    @Test("A stack nobody has sold out of is not closed, however empty")
    func emptyStackIsNotClosed() {
        let vesaf = FundTestFactory.instrument(pricePerUnit: 30_000)
        let group = FundPositionGroup(
            instrument: vesaf,
            instrumentID: vesaf.id,
            holdings: [FundTestFactory.holding(in: vesaf, units: 0, averageCostPerUnit: 0)],
            sales: []
        )

        #expect(group.isFullyClosed == false)
        #expect(group.hasSales == false)
    }

    @Test("Grouping hands each stack only its own sales")
    func groupingSplitsSalesByStack() {
        let vesaf = FundTestFactory.instrument(symbol: "VESAF", pricePerUnit: 30_000)
        let diamond = FundTestFactory.instrument(
            symbol: "FUEVFVND",
            kind: .etf,
            pricePerUnit: 40_000
        )
        let vesafLot = FundTestFactory.holding(in: vesaf, units: 300, averageCostPerUnit: 20_000)
        let diamondLot = FundTestFactory.holding(
            in: diamond,
            units: 100,
            averageCostPerUnit: 30_000
        )
        let sales = [
            FundTestFactory.sale(of: vesafLot, units: 100, pricePerUnit: 32_000),
            FundTestFactory.sale(of: diamondLot, units: 50, pricePerUnit: 45_000),
        ]

        let groups = FundSummary.groups(
            holdings: [vesafLot, diamondLot],
            instruments: [vesaf, diamond],
            sales: sales
        )

        let vesafGroup = groups.first { $0.symbol == "VESAF" }
        let diamondGroup = groups.first { $0.symbol == "FUEVFVND" }

        #expect(vesafGroup?.sales.count == 1)
        #expect(vesafGroup?.units == 200)
        #expect(diamondGroup?.sales.count == 1)
        #expect(diamondGroup?.units == 50)
    }
}
