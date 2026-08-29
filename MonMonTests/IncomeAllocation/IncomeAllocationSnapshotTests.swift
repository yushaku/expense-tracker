import Foundation
import Testing

@testable import MonMon

@Suite("Income allocation snapshot")
struct IncomeAllocationSnapshotTests {
    private let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("A full six-jar split reconciles exactly to the income")
    func fullAllocationReconcilesExactly() throws {
        let jars = [
            jar(id: uuid(1), name: "Necessities", percent: 55),
            jar(id: uuid(2), name: "Investment", percent: 10),
            jar(id: uuid(3), name: "Education", percent: 10),
            jar(id: uuid(4), name: "Savings", percent: 10),
            jar(id: uuid(5), name: "Play", percent: 10),
            jar(id: uuid(6), name: "Giving", percent: 5),
        ]

        let snapshot = try IncomeAllocationSnapshot.capture(
            amount: 30_000_000,
            jars: jars,
            capturedAt: capturedAt,
            isEstimated: false
        )

        #expect(
            snapshot.slices.map(\.amount)
                == [16_500_000, 3_000_000, 3_000_000, 3_000_000, 3_000_000, 1_500_000]
        )
        #expect(snapshot.allocatedAmount == 30_000_000)
        #expect(snapshot.unallocatedAmount == 0)
        #expect(snapshot.reconciledAmount == snapshot.sourceAmount)
    }

    @Test("An incomplete jar setup leaves an explicit unallocated remainder")
    func partialAllocationLeavesRemainder() throws {
        let snapshot = try IncomeAllocationSnapshot.capture(
            amount: 101,
            jars: [jar(id: uuid(1), name: "Necessities", percent: 50)],
            capturedAt: capturedAt,
            isEstimated: false
        )

        #expect(snapshot.slices.first?.amount == 50)
        #expect(snapshot.unallocatedAmount == 51)
        #expect(snapshot.reconciledAmount == 101)
    }

    @Test("Largest-remainder rounding breaks ties by stable jar identity")
    func roundingUsesStableIdentity() throws {
        let lowID = uuid(1)
        let highID = uuid(2)

        let snapshot = try IncomeAllocationSnapshot.capture(
            amount: 1,
            jars: [
                jar(id: highID, name: "Second", percent: 50),
                jar(id: lowID, name: "First", percent: 50),
            ],
            capturedAt: capturedAt,
            isEstimated: false
        )

        #expect(snapshot.slices.first { $0.jarID == lowID }?.amount == 1)
        #expect(snapshot.slices.first { $0.jarID == highID }?.amount == 0)
        #expect(snapshot.unallocatedAmount == 0)
    }

    @Test("Encoding freezes jar presentation and percentages")
    func codecPreservesFrozenJarValues() throws {
        let sourceJar = jar(id: uuid(1), name: "Savings", percent: 60)
        let snapshot = try IncomeAllocationSnapshot.capture(
            amount: 1_000,
            jars: [sourceJar],
            capturedAt: capturedAt,
            isEstimated: true
        )

        sourceJar.name = "Renamed"
        sourceJar.allocationPercent = 10
        let decoded = try IncomeAllocationSnapshotCodec.decode(
            IncomeAllocationSnapshotCodec.encode(snapshot)
        )

        #expect(decoded.slices.first?.name == "Savings")
        #expect(decoded.slices.first?.percent == 60)
        #expect(decoded.slices.first?.amount == 600)
        #expect(decoded.isEstimated)
    }

    @Test("Refreshing an edited amount keeps the captured percentages")
    func refreshKeepsCapturedPercentages() throws {
        let snapshot = try IncomeAllocationSnapshot.capture(
            amount: 1_000,
            jars: [
                jar(id: uuid(1), name: "Savings", percent: 60),
                jar(id: uuid(2), name: "Investment", percent: 40),
            ],
            capturedAt: capturedAt,
            isEstimated: false
        )

        let refreshed = try snapshot.refreshing(sourceAmount: 2_000)

        #expect(refreshed.slices.map(\.amount) == [1_200, 800])
        #expect(refreshed.slices.map(\.percent) == [60, 40])
        #expect(refreshed.capturedAt == capturedAt)
        #expect(refreshed.reconciledAmount == 2_000)
    }

    private func jar(id: UUID, name: String, percent: Decimal) -> BudgetJar {
        BudgetJar(
            id: id,
            name: name,
            allocationPercent: percent,
            role: .custom,
            symbolName: "tag.fill",
            colorName: "green",
            createdAt: capturedAt
        )
    }

    private func uuid(_ suffix: Int) -> UUID {
        guard
            let id = UUID(
                uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))
        else {
            preconditionFailure("Invalid test UUID")
        }
        return id
    }
}
