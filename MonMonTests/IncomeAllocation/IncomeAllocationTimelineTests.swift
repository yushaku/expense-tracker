import Foundation
import Testing

@testable import MonMon

@Suite("Income allocation timeline preparation")
@MainActor
struct IncomeAllocationTimelineTests {
    @Test("Only the selected month's income appears newest first with provenance")
    func selectedMonthIsPrepared() throws {
        let jar = makeJar()
        let oneOff = makeTransaction(
            kind: .income,
            amount: 1_000,
            occurredAt: date(2026, 8, 5)
        )
        let imported = makeTransaction(
            kind: .income,
            amount: 2_000,
            occurredAt: date(2026, 8, 15),
            sourceImportID: String(repeating: "a", count: 64)
        )
        let recurring = makeTransaction(
            kind: .income,
            amount: 3_000,
            occurredAt: date(2026, 8, 25),
            sourceRuleID: UUID()
        )
        let previousMonth = makeTransaction(
            kind: .income,
            amount: 4_000,
            occurredAt: date(2026, 7, 25)
        )
        let expense = makeTransaction(
            kind: .expense,
            amount: 5_000,
            occurredAt: date(2026, 8, 26)
        )
        for transaction in [oneOff, imported, recurring, previousMonth, expense] {
            try IncomeAllocationLifecycle.captureNew(
                on: transaction,
                jars: [jar],
                capturedAt: transaction.createdAt
            )
        }

        let result = IncomeAllocationTimeline.prepare(
            transactions: [oneOff, imported, recurring, previousMonth, expense],
            monthContaining: date(2026, 8, 1)
        )

        #expect(result.events.map(\.id) == [recurring.id, imported.id, oneOff.id])
        #expect(result.events.map(\.source) == [.recurring, .imported, .oneOff])
        #expect(result.totalAmount == 6_000)
        #expect(result.invalidCount == 0)
    }

    @Test("Malformed and missing snapshots are counted without hiding valid income")
    func invalidSnapshotsAreReported() throws {
        let valid = makeTransaction(kind: .income, amount: 1_000, occurredAt: date(2026, 8, 5))
        try IncomeAllocationLifecycle.captureNew(
            on: valid,
            jars: [makeJar()],
            capturedAt: valid.createdAt
        )
        let malformed = makeTransaction(
            kind: .income,
            amount: 2_000,
            occurredAt: date(2026, 8, 6)
        )
        malformed.incomeAllocationSnapshot = "not-json"
        let missing = makeTransaction(kind: .income, amount: 3_000, occurredAt: date(2026, 8, 7))

        let result = IncomeAllocationTimeline.prepare(
            transactions: [valid, malformed, missing],
            monthContaining: date(2026, 8, 1)
        )

        #expect(result.events.map(\.id) == [valid.id])
        #expect(result.invalidCount == 2)
    }

    private func makeJar() -> BudgetJar {
        BudgetJar(
            id: UUID(),
            name: "Savings",
            allocationPercent: 100,
            role: .savings,
            symbolName: "building.columns.fill",
            colorName: "yellow",
            createdAt: date(2026, 1, 1)
        )
    }

    private func makeTransaction(
        kind: TransactionKind,
        amount: Decimal,
        occurredAt: Date,
        sourceRuleID: UUID? = nil,
        sourceImportID: String? = nil
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: kind,
            amount: amount,
            occurredAt: occurredAt,
            note: "Income",
            accountID: UUID(),
            categoryID: UUID(),
            sourceRuleID: sourceRuleID,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt.addingTimeInterval(60),
            sourceImportID: sourceImportID
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        TransactionPeriod.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: 12)
        ) ?? Date(timeIntervalSince1970: 0)
    }
}
