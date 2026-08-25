import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Statement import provenance")
@MainActor
struct StatementImportProvenanceTests {
    private let importedSource = String(repeating: "a", count: 64)

    @Test("Import source IDs accept only lowercase SHA-256 hex")
    func validatesImportSourceID() {
        #expect(ImportSourceID(rawValue: importedSource)?.rawValue == importedSource)

        for invalidValue in [
            "",
            String(repeating: "a", count: 63),
            String(repeating: "a", count: 65),
            String(repeating: "A", count: 64),
            String(repeating: "g", count: 64),
        ] {
            #expect(ImportSourceID(rawValue: invalidValue) == nil)
        }
    }

    @Test("Manual records have no import provenance")
    func manualRecordsDefaultToNilProvenance() {
        let transaction = makeTransaction()
        let transfer = makeTransfer()

        #expect(transaction.sourceImportID == nil)
        #expect(transfer.sourceAccountImportID == nil)
        #expect(transfer.destinationAccountImportID == nil)
    }

    @Test("Import provenance round trips through SwiftData")
    func provenanceRoundTrips() throws {
        let container = try ModelContainer(
            for: MoneyTransaction.self, AccountTransfer.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let transaction = makeTransaction(sourceImportID: importedSource)
        let transfer = makeTransfer(
            sourceAccountImportID: importedSource,
            destinationAccountImportID: String(repeating: "b", count: 64)
        )
        context.insert(transaction)
        context.insert(transfer)
        try context.save()

        let storedTransaction = try #require(
            try context.fetch(FetchDescriptor<MoneyTransaction>()).first
        )
        let storedTransfer = try #require(
            try context.fetch(FetchDescriptor<AccountTransfer>()).first
        )

        #expect(storedTransaction.sourceImportID == importedSource)
        #expect(storedTransfer.sourceAccountImportID == importedSource)
        #expect(storedTransfer.destinationAccountImportID == String(repeating: "b", count: 64))
    }

    private func makeTransaction(sourceImportID: String? = nil) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: .expense,
            amount: 125_000,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            note: "Synthetic purchase",
            accountID: UUID(),
            categoryID: nil,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: Date(timeIntervalSince1970: 1_700_000_001),
            sourceImportID: sourceImportID
        )
    }

    private func makeTransfer(
        sourceAccountImportID: String? = nil,
        destinationAccountImportID: String? = nil
    ) -> AccountTransfer {
        AccountTransfer(
            id: UUID(),
            amount: 500_000,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            note: "Synthetic transfer",
            sourceAccountID: UUID(),
            destinationAccountID: UUID(),
            currencyCode: VNDCurrency.code,
            createdAt: Date(timeIntervalSince1970: 1_700_000_001),
            sourceAccountImportID: sourceAccountImportID,
            destinationAccountImportID: destinationAccountImportID
        )
    }
}
