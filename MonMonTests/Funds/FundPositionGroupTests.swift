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
            instruments: [vesaf, dcds]
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
            ]
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
            ]
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
            instruments: [vesaf]
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
            holdings: [FundTestFactory.holding(in: vesaf, units: 0, averageCostPerUnit: 0)]
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
}
