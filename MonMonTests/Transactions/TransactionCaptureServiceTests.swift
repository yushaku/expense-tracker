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
        context.insert(
            CashAccount(
                id: accountID,
                name: "TPBank",
                kind: .bank,
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
        try context.save()

        let suiteName = "TransactionCaptureServiceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(accountID.uuidString, forKey: TransactionDefaults.accountStorageKey)
        defaults.set(categoryID.uuidString, forKey: TransactionDefaults.categoryStorageKey)

        return Fixture(
            container: container,
            service: TransactionCaptureService(container: container, defaults: defaults),
            accountID: accountID,
            categoryID: categoryID
        )
    }

    private struct Fixture {
        let container: ModelContainer
        let service: TransactionCaptureService
        let accountID: UUID
        let categoryID: UUID
    }
}
