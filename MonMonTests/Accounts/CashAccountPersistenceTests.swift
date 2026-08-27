import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("Cash account persistence")
@MainActor
struct CashAccountPersistenceTests {
    @Test("Saving and fetching preserves every cash account field")
    func savingAndFetchingPreservesEveryField() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CashAccount.self,
            configurations: configuration
        )
        let context = container.mainContext
        let id = try #require(UUID(uuidString: "8B9F388D-0DF7-4C70-A269-00C3F6A754AF"))
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let openingBalance = Decimal(12_345_678)
        let account = CashAccount(
            id: id,
            name: "Visa",
            kind: .credit,
            openingBalance: -openingBalance,
            creditLimit: 50_000_000,
            currencyCode: "VND",
            createdAt: createdAt
        )

        context.insert(account)
        try context.save()

        let accounts = try context.fetch(FetchDescriptor<CashAccount>())
        let savedAccount = try #require(accounts.first)

        #expect(accounts.count == 1)
        #expect(savedAccount.id == id)
        #expect(savedAccount.name == "Visa")
        #expect(savedAccount.kind == .credit)
        #expect(savedAccount.openingBalance == -openingBalance)
        #expect(savedAccount.creditLimit == 50_000_000)
        #expect(savedAccount.currencyCode == "VND")
        #expect(savedAccount.createdAt == createdAt)
    }
}
