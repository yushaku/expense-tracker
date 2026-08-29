import Foundation
import SwiftData

@MainActor
enum IncomeAllocationLifecycle {
    struct BackfillReport: Equatable {
        var captured: Int
        var invalid: Int
    }

    static func captureNew(
        on transaction: MoneyTransaction,
        jars: [BudgetJar],
        capturedAt: Date
    ) throws {
        transaction.incomeAllocationSnapshot = try encodedSnapshot(
            kind: transaction.kind,
            amount: transaction.amount,
            jars: jars,
            capturedAt: capturedAt,
            isEstimated: false
        )
    }

    static func snapshot(in transaction: MoneyTransaction) throws -> IncomeAllocationSnapshot? {
        guard let encoded = transaction.incomeAllocationSnapshot else {
            return nil
        }
        let snapshot = try IncomeAllocationSnapshotCodec.decode(encoded)
        guard transaction.kind == .income, snapshot.sourceAmount == transaction.amount else {
            throw IncomeAllocationSnapshotError.invalidSnapshot
        }
        return snapshot
    }

    static func snapshotForEdit(
        _ transaction: MoneyTransaction,
        newKind: TransactionKind,
        newAmount: Decimal,
        currentJars: [BudgetJar],
        capturedAt: Date
    ) throws -> String? {
        guard newKind == .income else {
            return nil
        }

        guard transaction.kind == .income else {
            guard transaction.incomeAllocationSnapshot == nil else {
                throw IncomeAllocationSnapshotError.invalidSnapshot
            }
            return try encodedSnapshot(
                kind: newKind,
                amount: newAmount,
                jars: currentJars,
                capturedAt: capturedAt,
                isEstimated: false
            )
        }

        guard let existing = try snapshot(in: transaction) else {
            return try encodedSnapshot(
                kind: newKind,
                amount: newAmount,
                jars: currentJars,
                capturedAt: capturedAt,
                isEstimated: true
            )
        }
        guard newAmount != existing.sourceAmount else {
            return transaction.incomeAllocationSnapshot
        }
        return try IncomeAllocationSnapshotCodec.encode(
            existing.refreshing(sourceAmount: newAmount)
        )
    }

    static func backfillMissing(
        in context: ModelContext,
        capturedAt: Date = .now
    ) throws -> BackfillReport {
        let jars = try context.fetch(FetchDescriptor<BudgetJar>())
        let descriptor = FetchDescriptor<MoneyTransaction>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let transactions = try context.fetch(descriptor)
        var report = BackfillReport(captured: 0, invalid: 0)
        var staged: [(transaction: MoneyTransaction, snapshot: String)] = []

        for transaction in transactions {
            guard transaction.kind == .income else {
                if transaction.incomeAllocationSnapshot != nil {
                    report.invalid += 1
                }
                continue
            }

            if transaction.incomeAllocationSnapshot == nil {
                let snapshot = try encodedSnapshot(
                    kind: .income,
                    amount: transaction.amount,
                    jars: jars,
                    capturedAt: capturedAt,
                    isEstimated: true
                )
                guard let snapshot else {
                    throw IncomeAllocationSnapshotError.invalidSnapshot
                }
                staged.append((transaction, snapshot))
                report.captured += 1
            } else {
                do {
                    _ = try snapshot(in: transaction)
                } catch {
                    report.invalid += 1
                }
            }
        }

        guard !staged.isEmpty else {
            return report
        }
        for item in staged {
            item.transaction.incomeAllocationSnapshot = item.snapshot
        }
        do {
            try context.save()
        } catch {
            for item in staged {
                item.transaction.incomeAllocationSnapshot = nil
            }
            throw error
        }
        return report
    }

    private static func encodedSnapshot(
        kind: TransactionKind,
        amount: Decimal,
        jars: [BudgetJar],
        capturedAt: Date,
        isEstimated: Bool
    ) throws -> String? {
        guard kind == .income else {
            return nil
        }
        let snapshot = try IncomeAllocationSnapshot.capture(
            amount: amount,
            jars: jars,
            capturedAt: capturedAt,
            isEstimated: isEstimated
        )
        return try IncomeAllocationSnapshotCodec.encode(snapshot)
    }
}
