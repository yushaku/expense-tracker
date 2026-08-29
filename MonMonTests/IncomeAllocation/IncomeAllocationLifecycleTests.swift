import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Income allocation lifecycle")
@MainActor
struct IncomeAllocationLifecycleTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("A new income captures current jars while an expense stays empty")
    func newTransactionCaptureFollowsDirection() throws {
        let jar = makeJar(name: "Savings", percent: 60)

        let income = makeTransaction(kind: .income, amount: 1_000)
        try IncomeAllocationLifecycle.captureNew(on: income, jars: [jar], capturedAt: now)
        let snapshot = try IncomeAllocationLifecycle.snapshot(in: income)

        let expense = makeTransaction(kind: .expense, amount: 1_000)
        try IncomeAllocationLifecycle.captureNew(on: expense, jars: [jar], capturedAt: now)

        #expect(snapshot?.slices.first?.amount == 600)
        #expect(snapshot?.isEstimated == false)
        #expect(expense.incomeAllocationSnapshot == nil)
    }

    @Test("Editing an income amount keeps its frozen jar setup")
    func incomeEditKeepsFrozenSetup() throws {
        let originalJar = makeJar(name: "Savings", percent: 60)
        let transaction = makeTransaction(kind: .income, amount: 1_000)
        try IncomeAllocationLifecycle.captureNew(
            on: transaction,
            jars: [originalJar],
            capturedAt: now
        )
        originalJar.name = "Renamed"
        originalJar.allocationPercent = 10

        transaction.incomeAllocationSnapshot = try IncomeAllocationLifecycle.snapshotForEdit(
            transaction,
            newKind: .income,
            newAmount: 2_000,
            currentJars: [originalJar],
            capturedAt: now.addingTimeInterval(60)
        )
        transaction.amount = 2_000
        let snapshot = try IncomeAllocationLifecycle.snapshot(in: transaction)

        #expect(snapshot?.slices.first?.name == "Savings")
        #expect(snapshot?.slices.first?.percent == 60)
        #expect(snapshot?.slices.first?.amount == 1_200)
        #expect(snapshot?.capturedAt == now)
    }

    @Test("Changing direction creates or removes the explanation")
    func directionEditCreatesAndRemovesSnapshot() throws {
        let jar = makeJar(name: "Savings", percent: 100)
        let expense = makeTransaction(kind: .expense, amount: 500)

        expense.incomeAllocationSnapshot = try IncomeAllocationLifecycle.snapshotForEdit(
            expense,
            newKind: .income,
            newAmount: 500,
            currentJars: [jar],
            capturedAt: now
        )
        expense.kind = .income
        #expect(try IncomeAllocationLifecycle.snapshot(in: expense)?.isEstimated == false)

        let removed = try IncomeAllocationLifecycle.snapshotForEdit(
            expense,
            newKind: .expense,
            newAmount: 500,
            currentJars: [jar],
            capturedAt: now
        )
        #expect(removed == nil)
    }

    @Test("A malformed snapshot is reported and never replaced")
    func malformedSnapshotIsNotOverwritten() throws {
        let transaction = makeTransaction(kind: .income, amount: 1_000)
        transaction.incomeAllocationSnapshot = "not-json"

        #expect(throws: Error.self) {
            try IncomeAllocationLifecycle.snapshotForEdit(
                transaction,
                newKind: .income,
                newAmount: 2_000,
                currentJars: [makeJar(name: "Savings", percent: 100)],
                capturedAt: now
            )
        }
        #expect(transaction.incomeAllocationSnapshot == "not-json")
    }

    @Test("Legacy backfill is estimated, idempotent, and preserves malformed data")
    func backfillIsSafeAndIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(makeJar(name: "Savings", percent: 100))
        let missing = makeTransaction(kind: .income, amount: 1_000)
        let malformed = makeTransaction(kind: .income, amount: 2_000)
        malformed.incomeAllocationSnapshot = "not-json"
        context.insert(missing)
        context.insert(malformed)
        try context.save()

        let first = try IncomeAllocationLifecycle.backfillMissing(in: context, capturedAt: now)
        let second = try IncomeAllocationLifecycle.backfillMissing(in: context, capturedAt: now)

        #expect(first == .init(captured: 1, invalid: 1))
        #expect(second == .init(captured: 0, invalid: 1))
        #expect(try IncomeAllocationLifecycle.snapshot(in: missing)?.isEstimated == true)
        #expect(malformed.incomeAllocationSnapshot == "not-json")
    }

    @Test("Backfill stages every snapshot before mutating legacy rows")
    func backfillDoesNotPartiallyApply() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(makeJar(name: "Savings", percent: 100))
        let valid = makeTransaction(kind: .income, amount: 1_000)
        valid.createdAt = now
        let invalid = makeTransaction(kind: .income, amount: 0)
        invalid.createdAt = now.addingTimeInterval(60)
        context.insert(valid)
        context.insert(invalid)
        try context.save()

        #expect(throws: IncomeAllocationSnapshotError.invalidAmount) {
            try IncomeAllocationLifecycle.backfillMissing(in: context, capturedAt: now)
        }
        #expect(valid.incomeAllocationSnapshot == nil)
        #expect(invalid.incomeAllocationSnapshot == nil)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeJar(name: String, percent: Decimal) -> BudgetJar {
        BudgetJar(
            id: UUID(),
            name: name,
            allocationPercent: percent,
            role: .custom,
            symbolName: "tag.fill",
            colorName: "green",
            createdAt: now
        )
    }

    private func makeTransaction(kind: TransactionKind, amount: Decimal) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: kind,
            amount: amount,
            occurredAt: now,
            note: "Income",
            accountID: UUID(),
            categoryID: UUID(),
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: now
        )
    }
}
