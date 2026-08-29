import Foundation

struct IncomeAllocationSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1

    struct Slice: Codable, Equatable, Sendable {
        let jarID: UUID
        let name: String
        let symbolName: String
        let colorName: String
        let percent: Decimal
        let amount: Decimal
    }

    let version: Int
    let sourceAmount: Decimal
    let capturedAt: Date
    let isEstimated: Bool
    let slices: [Slice]
    let unallocatedAmount: Decimal

    var allocatedAmount: Decimal {
        slices.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var reconciledAmount: Decimal {
        allocatedAmount + unallocatedAmount
    }

    static func capture(
        amount: Decimal,
        jars: [BudgetJar],
        capturedAt: Date,
        isEstimated: Bool
    ) throws -> IncomeAllocationSnapshot {
        let inputs = jars.map {
            AllocationInput(
                id: $0.id,
                name: $0.name,
                symbolName: $0.symbolName,
                colorName: $0.colorName,
                percent: $0.allocationPercent,
                createdAt: $0.createdAt
            )
        }
        return try make(
            amount: amount,
            inputs: inputs,
            capturedAt: capturedAt,
            isEstimated: isEstimated
        )
    }

    func refreshing(sourceAmount: Decimal) throws -> IncomeAllocationSnapshot {
        let inputs = slices.enumerated().map { index, slice in
            AllocationInput(
                id: slice.jarID,
                name: slice.name,
                symbolName: slice.symbolName,
                colorName: slice.colorName,
                percent: slice.percent,
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        return try Self.make(
            amount: sourceAmount,
            inputs: inputs,
            capturedAt: capturedAt,
            isEstimated: isEstimated
        )
    }

    fileprivate func validated() throws -> IncomeAllocationSnapshot {
        guard version == Self.currentVersion else {
            throw IncomeAllocationSnapshotError.unsupportedVersion(version)
        }
        guard sourceAmount > 0, capturedAt.timeIntervalSince1970.isFinite else {
            throw IncomeAllocationSnapshotError.invalidSnapshot
        }
        guard Set(slices.map(\.jarID)).count == slices.count else {
            throw IncomeAllocationSnapshotError.invalidSnapshot
        }
        guard
            slices.allSatisfy({
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.symbolName.isEmpty
                    && !$0.colorName.isEmpty
                    && $0.percent >= 0
                    && $0.amount >= 0
            }),
            slices.reduce(Decimal.zero, { $0 + $1.percent }) <= 100,
            unallocatedAmount >= 0,
            reconciledAmount == sourceAmount
        else {
            throw IncomeAllocationSnapshotError.invalidSnapshot
        }
        let expected = Self.distribution(
            amount: sourceAmount,
            identities: slices.map { ($0.jarID, $0.percent) }
        )
        guard
            slices.map(\.amount) == expected.amounts,
            unallocatedAmount == expected.unallocatedAmount
        else {
            throw IncomeAllocationSnapshotError.invalidSnapshot
        }
        return self
    }

    private static func make(
        amount: Decimal,
        inputs: [AllocationInput],
        capturedAt: Date,
        isEstimated: Bool
    ) throws -> IncomeAllocationSnapshot {
        guard amount > 0 else {
            throw IncomeAllocationSnapshotError.invalidAmount
        }
        guard Set(inputs.map(\.id)).count == inputs.count else {
            throw IncomeAllocationSnapshotError.invalidJarConfiguration
        }
        guard
            inputs.allSatisfy({
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && $0.percent >= 0
            }),
            inputs.reduce(Decimal.zero, { $0 + $1.percent }) <= 100
        else {
            throw IncomeAllocationSnapshotError.invalidJarConfiguration
        }

        let ordered = inputs.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        let distribution = distribution(
            amount: amount,
            identities: ordered.map { ($0.id, $0.percent) }
        )

        let slices = zip(ordered, distribution.amounts).map { input, allocation in
            Slice(
                jarID: input.id,
                name: input.name,
                symbolName: input.symbolName,
                colorName: input.colorName,
                percent: input.percent,
                amount: allocation
            )
        }
        return try IncomeAllocationSnapshot(
            version: currentVersion,
            sourceAmount: amount,
            capturedAt: capturedAt,
            isEstimated: isEstimated,
            slices: slices,
            unallocatedAmount: distribution.unallocatedAmount
        ).validated()
    }

    private static func distribution(
        amount: Decimal,
        identities: [(id: UUID, percent: Decimal)]
    ) -> (amounts: [Decimal], unallocatedAmount: Decimal) {
        let totalPercent = identities.reduce(Decimal.zero) { $0 + $1.percent }
        let target = roundedDown(amount * totalPercent / 100)
        let raw = identities.map { amount * $0.percent / 100 }
        var amounts = raw.map(roundedDown)
        let missingUnits = NSDecimalNumber(decimal: target - amounts.reduce(0, +)).intValue

        let correctionOrder = raw.indices.sorted {
            let leftRemainder = raw[$0] - amounts[$0]
            let rightRemainder = raw[$1] - amounts[$1]
            if leftRemainder != rightRemainder { return leftRemainder > rightRemainder }
            return identities[$0].id.uuidString < identities[$1].id.uuidString
        }
        for index in correctionOrder.prefix(max(0, missingUnits)) {
            amounts[index] += 1
        }
        return (amounts, amount - target)
    }

    private static func roundedDown(_ value: Decimal) -> Decimal {
        var source = value
        var result = Decimal.zero
        NSDecimalRound(&result, &source, 0, .down)
        return result
    }
}

enum IncomeAllocationSnapshotCodec {
    static func encode(_ snapshot: IncomeAllocationSnapshot) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot.validated())
        guard let value = String(data: data, encoding: .utf8) else {
            throw IncomeAllocationSnapshotError.invalidEncoding
        }
        return value
    }

    static func decode(_ value: String) throws -> IncomeAllocationSnapshot {
        guard let data = value.data(using: .utf8) else {
            throw IncomeAllocationSnapshotError.invalidEncoding
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(IncomeAllocationSnapshot.self, from: data).validated()
    }
}

enum IncomeAllocationSnapshotError: Error, Equatable {
    case invalidAmount
    case invalidJarConfiguration
    case invalidSnapshot
    case invalidEncoding
    case unsupportedVersion(Int)
}

private struct AllocationInput {
    let id: UUID
    let name: String
    let symbolName: String
    let colorName: String
    let percent: Decimal
    let createdAt: Date
}
