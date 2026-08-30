import Foundation
import SwiftData
import Testing

@testable import MonMon

@MainActor
@Suite("Transaction capture persistence")
struct TransactionCaptureServiceTests {
    private let now = Date(timeIntervalSince1970: 1_735_776_000)

    @Test("A ready capture creates one transaction and no pending item")
    func readyCaptureCreatesTransaction() throws {
        let fixture = try makeFixture()
        let prepared = try fixture.service.prepare("50k ăn trưa", now: now)

        let result = try fixture.service.commit(prepared, id: UUID(), createdAt: now)
        let context = ModelContext(fixture.container)
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let pending = try context.fetch(FetchDescriptor<PendingTransactionCapture>())

        #expect(result.disposition == .transaction)
        #expect(transactions.count == 1)
        #expect(transactions.first?.amount == 50_000)
        #expect(transactions.first?.accountID == fixture.accountID)
        #expect(transactions.first?.categoryID == fixture.categoryID)
        #expect(pending.isEmpty)
    }

    @Test("A ready income captures its current jar allocation")
    func readyIncomeCapturesAllocation() throws {
        let fixture = try makeFixture()
        let capture = ParsedTransactionCapture(
            rawText: "Lương 5 triệu",
            kind: .income,
            amount: 5_000_000,
            occurredAt: now,
            note: "Lương",
            accountID: fixture.accountID,
            categoryID: fixture.incomeCategoryID,
            issues: []
        )

        let result = try fixture.service.commit(capture, createdAt: now)
        let context = ModelContext(fixture.container)
        let transaction = try #require(
            context.fetch(FetchDescriptor<MoneyTransaction>()).first
        )

        #expect(result.disposition == .transaction)
        #expect(
            try IncomeAllocationLifecycle.snapshot(in: transaction)?.allocatedAmount == 5_000_000
        )
    }

    @Test("An uncertain capture is staged without changing financial records")
    func uncertainCaptureIsStaged() throws {
        let fixture = try makeFixture()
        let prepared = try fixture.service.prepare("ăn trưa tiền mặt", now: now)

        let result = try fixture.service.commit(prepared, id: UUID(), createdAt: now)
        let context = ModelContext(fixture.container)
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let pending = try context.fetch(FetchDescriptor<PendingTransactionCapture>())

        #expect(result.disposition == .pendingReview)
        #expect(transactions.isEmpty)
        #expect(pending.count == 1)
        #expect(pending.first?.rawText == "ăn trưa tiền mặt")
        #expect(pending.first?.issues.contains(.missingAmount) == true)
    }

    @Test("The intent commits a ready entry in one step")
    func intentCommitsReadyEntryImmediately() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )

        let result = try await dependency.record("50k ăn trưa")
        let context = ModelContext(fixture.container)

        #expect(result.disposition == .transaction)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
    }

    @Test("The intent stages an uncertain entry in one step")
    func intentStagesUncertainEntryImmediately() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )

        let result = try await dependency.record("ăn trưa tiền mặt")
        let context = ModelContext(fixture.container)

        #expect(result.disposition == .pendingReview)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).count == 1)
    }

    @Test("Ready-only intent capture commits one expense without staging review")
    func readyOnlyIntentCommitsExpense() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )

        let result = try await dependency.recordReady("35.000 ☕")
        let context = ModelContext(fixture.container)
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())

        #expect(result.disposition == .transaction)
        #expect(transactions.count == 1)
        #expect(transactions.first?.kind == .expense)
        #expect(transactions.first?.amount == 35_000)
        #expect(transactions.first?.note == "☕")
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
    }

    @Test("Ready-only intent capture writes nothing when defaults are unavailable")
    func readyOnlyIntentRejectsMissingDefaults() async throws {
        let fixture = try makeFixture()
        fixture.defaults.removeObject(forKey: TransactionDefaults.accountStorageKey)
        fixture.defaults.removeObject(forKey: TransactionDefaults.categoryStorageKey)
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )

        await #expect(throws: TransactionCaptureServiceError.incompleteCapture) {
            try await dependency.recordReady("35.000 ☕")
        }

        let context = ModelContext(fixture.container)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
    }

    @Test("Quick expense uses its configured category instead of the global default")
    func quickExpenseUsesConfiguredCategory() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )
        let preset = try QuickExpensePreset(
            slot: .fuel,
            symbol: "⛽",
            amount: 100_000,
            categoryID: fixture.transportCategoryID
        )

        let result = try await dependency.recordQuickExpense(preset)

        let context = ModelContext(fixture.container)
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        #expect(result.disposition == .transaction)
        #expect(transactions.count == 1)
        #expect(transactions.first?.amount == 100_000)
        #expect(transactions.first?.categoryID == fixture.transportCategoryID)
        #expect(transactions.first?.accountID == fixture.accountID)
        #expect(transactions.first?.note == "⛽")
    }

    @Test("Legacy quick expense without a category uses the global default")
    func quickExpenseWithoutCategoryUsesDefault() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )
        let preset = try QuickExpensePreset(
            slot: .coffee,
            symbol: "☕",
            amount: 35_000
        )

        _ = try await dependency.recordQuickExpense(preset)

        let context = ModelContext(fixture.container)
        let transaction = try #require(
            context.fetch(FetchDescriptor<MoneyTransaction>()).first
        )
        #expect(transaction.categoryID == fixture.categoryID)
    }

    @Test("Quick expense rejects a deleted configured category without writing")
    func quickExpenseRejectsDeletedCategory() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )
        let preset = try QuickExpensePreset(
            slot: .coffee,
            symbol: "☕",
            amount: 35_000,
            categoryID: UUID()
        )

        await #expect(throws: TransactionCaptureServiceError.incompleteCapture) {
            try await dependency.recordQuickExpense(preset)
        }

        let context = ModelContext(fixture.container)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
    }

    @Test("Quick expense rejects a configured income category without writing")
    func quickExpenseRejectsIncomeCategory() async throws {
        let fixture = try makeFixture()
        let dependency = TransactionCaptureIntentDependency(
            container: fixture.container,
            defaults: fixture.defaults
        )
        let preset = try QuickExpensePreset(
            slot: .coffee,
            symbol: "☕",
            amount: 35_000,
            categoryID: fixture.incomeCategoryID
        )

        await #expect(throws: TransactionCaptureServiceError.incompleteCapture) {
            try await dependency.recordQuickExpense(preset)
        }

        let context = ModelContext(fixture.container)
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
    }

    @Test("A stale prepared capture is rejected before writing")
    func stalePreparedCaptureIsRejected() throws {
        let fixture = try makeFixture()
        let prepared = try fixture.service.prepare("50k ăn trưa", now: now)
        let context = ModelContext(fixture.container)
        let accounts = try context.fetch(FetchDescriptor<CashAccount>())
        for account in accounts {
            context.delete(account)
        }
        try context.save()

        #expect(throws: TransactionCaptureServiceError.staleCapture) {
            try fixture.service.commit(prepared, id: UUID(), createdAt: now)
        }
        #expect(try context.fetch(FetchDescriptor<MoneyTransaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingTransactionCapture>()).isEmpty)
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let accountID = UUID()
        let categoryID = UUID()
        let transportCategoryID = UUID()
        let incomeCategoryID = UUID()
        context.insert(
            CashAccount(
                id: accountID,
                name: "TPBank",
                kind: .normal,
                openingBalance: 0,
                currencyCode: VNDCurrency.code,
                createdAt: now
            )
        )
        context.insert(
            TransactionCategory(
                id: categoryID,
                name: "Ăn uống",
                kind: .expense,
                symbolName: "fork.knife",
                colorName: "peach",
                createdAt: now
            )
        )
        context.insert(
            TransactionCategory(
                id: transportCategoryID,
                name: "Đi lại",
                kind: .expense,
                symbolName: "car.fill",
                colorName: "blue",
                createdAt: now.addingTimeInterval(1)
            )
        )
        context.insert(
            TransactionCategory(
                id: incomeCategoryID,
                name: "Lương",
                kind: .income,
                symbolName: "banknote.fill",
                colorName: "green",
                createdAt: now.addingTimeInterval(2)
            )
        )
        context.insert(
            BudgetJar(
                id: UUID(),
                name: "Savings",
                allocationPercent: 100,
                role: .savings,
                symbolName: "building.columns.fill",
                colorName: "yellow",
                createdAt: now.addingTimeInterval(3)
            )
        )
        try context.save()

        let suiteName = "TransactionCaptureServiceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(accountID.uuidString, forKey: TransactionDefaults.accountStorageKey)
        defaults.set(categoryID.uuidString, forKey: TransactionDefaults.categoryStorageKey)

        return Fixture(
            container: container,
            service: TransactionCaptureService(container: container, defaults: defaults),
            defaults: defaults,
            accountID: accountID,
            categoryID: categoryID,
            transportCategoryID: transportCategoryID,
            incomeCategoryID: incomeCategoryID
        )
    }

    private struct Fixture {
        let container: ModelContainer
        let service: TransactionCaptureService
        let defaults: UserDefaults
        let accountID: UUID
        let categoryID: UUID
        let transportCategoryID: UUID
        let incomeCategoryID: UUID
    }
}
