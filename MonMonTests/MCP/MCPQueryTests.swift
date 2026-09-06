import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("MCP filtering and pagination")
struct MCPQueryTests {
    @Test("Defaults to 50, caps at 200, and rejects invalid limits")
    func limits() throws {
        #expect(try MCPQuery.parse(arguments: [:], for: .transactions).limit == 50)
        #expect(
            try MCPQuery.parse(arguments: ["limit": .int(200)], for: .transactions).limit == 200)
        #expect(throws: MCPToolError.invalidArgument) {
            try MCPQuery.parse(arguments: ["limit": .int(201)], for: .transactions)
        }
        #expect(throws: MCPToolError.invalidArgument) {
            try MCPQuery.parse(arguments: ["limit": .int(0)], for: .transactions)
        }
    }

    @Test("Stable cursor pagination has no duplicates or missing rows")
    func stableCursorPagination() throws {
        let sharedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let records = (0..<205).map { index in
            let id = UUID(
                uuid: (
                    0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, UInt8(index / 256), UInt8(index % 256)
                ))
            return MCPRecord(
                recordType: "MoneyTransaction",
                id: id,
                sortDate: index < 100 ? sharedDate : sharedDate.addingTimeInterval(-Double(index)),
                fields: [
                    "recordType": .string("MoneyTransaction"),
                    "id": .string(id.uuidString.lowercased()),
                    "createdAt": .string("2023-11-14T22:13:20Z"),
                    "kind": .string(index.isMultiple(of: 2) ? "expense" : "income"),
                    "accountID": .string("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"),
                ]
            )
        }

        var cursor: String?
        var seen: [UUID] = []
        repeat {
            var arguments: [String: MCPJSONValue] = ["limit": .int(50)]
            if let cursor { arguments["cursor"] = .string(cursor) }
            let query = try MCPQuery.parse(arguments: arguments, for: .transactions)
            let page = try MCPPaginator.page(records: records, query: query, tool: .transactions)
            seen.append(contentsOf: page.records.map(\.id))
            cursor = page.nextCursor
        } while cursor != nil

        #expect(seen.count == 205)
        #expect(Set(seen).count == 205)
        #expect(Set(seen) == Set(records.map(\.id)))
    }

    @Test("Filters IDs, created dates, business dates, enum, and foreign keys")
    func filters() throws {
        let wantedID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let accountID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let record = MCPRecord(
            recordType: "MoneyTransaction",
            id: wantedID,
            sortDate: date,
            fields: [
                "recordType": .string("MoneyTransaction"),
                "id": .string(wantedID.uuidString.lowercased()),
                "createdAt": .string("2023-11-14T22:13:20.000Z"),
                "kind": .string("expense"),
                "accountID": .string(accountID.uuidString.lowercased()),
            ]
        )
        let arguments: [String: MCPJSONValue] = [
            "id": .string(wantedID.uuidString),
            "createdAtFrom": .string("2023-11-14T00:00:00Z"),
            "createdAtTo": .string("2023-11-15T00:00:00Z"),
            "dateFrom": .string("2023-11-14T00:00:00Z"),
            "dateTo": .string("2023-11-15T00:00:00Z"),
            "kind": .string("expense"),
            "accountID": .string(accountID.uuidString),
        ]

        let query = try MCPQuery.parse(arguments: arguments, for: .transactions)
        #expect(
            try MCPPaginator.page(records: [record], query: query, tool: .transactions).records == [
                record
            ])
    }

    @Test("Rejects unknown filters, malformed values, and cross-tool cursors")
    func validation() throws {
        #expect(throws: MCPToolError.invalidArgument) {
            try MCPQuery.parse(arguments: ["direction": .string("borrowed")], for: .transactions)
        }
        #expect(throws: MCPToolError.invalidArgument) {
            try MCPQuery.parse(arguments: ["id": .string("not-a-uuid")], for: .transactions)
        }
        #expect(throws: MCPToolError.invalidArgument) {
            try MCPQuery.parse(arguments: ["dateFrom": .string("yesterday")], for: .transactions)
        }
        #expect(throws: MCPToolError.invalidArgument) {
            try MCPQuery.parse(arguments: ["accountID": .string("not-a-uuid")], for: .transactions)
        }
        #expect(throws: MCPToolError.invalidArgument) {
            try MCPQuery.parse(arguments: ["kind": .string("refund")], for: .transactions)
        }
        #expect(throws: MCPToolError.invalidArgument) {
            try MCPQuery.parse(
                arguments: ["recordType": .string("MoneyTransaction")], for: .savings)
        }

        let record = MCPRecord(
            recordType: "MoneyTransaction", id: UUID(), sortDate: .now,
            fields: ["recordType": .string("MoneyTransaction")]
        )
        let transactionPage = try MCPPaginator.page(
            records: [
                record,
                MCPRecord(
                    recordType: "MoneyTransaction", id: UUID(),
                    sortDate: record.sortDate.addingTimeInterval(-1),
                    fields: ["recordType": .string("MoneyTransaction")]
                ),
            ],
            query: MCPQuery(limit: 1),
            tool: .transactions
        )
        let cursor = try #require(transactionPage.nextCursor)
        #expect(throws: MCPToolError.invalidCursor) {
            let query = try MCPQuery.parse(arguments: ["cursor": .string(cursor)], for: .accounts)
            _ = try MCPPaginator.page(records: [], query: query, tool: .accounts)
        }
    }

    @Test("An explicitly empty ID list matches no records")
    func emptyIDs() throws {
        let record = MCPRecord(
            recordType: "CashAccount", id: UUID(), sortDate: .now,
            fields: ["recordType": .string("CashAccount")]
        )
        let query = try MCPQuery.parse(arguments: ["ids": .array([])], for: .accounts)

        #expect(
            try MCPPaginator.page(records: [record], query: query, tool: .accounts).records.isEmpty)
    }

    @MainActor
    @Test("SwiftData repository returns every model in combined domains")
    func repositoryGroups() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let id = UUID()
        container.mainContext.insert(
            SavingsDeposit(
                id: id, name: "Deposit", principal: 1, annualInterestRate: 1,
                termMonths: 1, openedAt: date, currencyCode: "VND", createdAt: date
            ))
        container.mainContext.insert(
            SavingsWithdrawal(
                id: UUID(), depositID: id, principal: 1, amountReceived: 1,
                destinationAccountID: UUID(), withdrawnAt: date, currencyCode: "VND",
                createdAt: date
            ))
        try container.mainContext.save()

        let records = try MCPDataRepository(context: container.mainContext).records(for: .savings)
        #expect(Set(records.map(\.recordType)) == ["SavingsDeposit", "SavingsWithdrawal"])
    }
}
