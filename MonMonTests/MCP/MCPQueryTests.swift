import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("MCP filtering and pagination")
struct MCPQueryTests {
    @Test("Tools reject parameters that do not apply to their records")
    func specificSchemas() throws {
        for key in ["limit", "cursor", "id", "ids", "dateFrom", "createdAtFrom"] {
            #expect(throws: MCPArgumentError.self) {
                try MCPQuery.parse(arguments: [key: .string("unused")], for: .dataStatus)
            }
        }
        for tool in [MCPTool.accounts, .categories, .budgetJars] {
            #expect(!tool.filterKeys.contains("dateFrom"))
            #expect(tool.filterKeys.contains("createdAtFrom"))
        }
        #expect(throws: MCPArgumentError.self) {
            try MCPQuery.parse(arguments: [:], for: .summary)
        }
    }

    @MainActor
    @Test(
        "Summary sums more than one page exactly, separates currencies and excludes the end instant"
    )
    func summaryTotals() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let from = Date(timeIntervalSince1970: 1_700_000_000)
        let end = from.addingTimeInterval(86400)
        let account = UUID()
        let jar = BudgetJar(
            id: UUID(), name: "Daily", allocationPercent: 100, role: .custom,
            symbolName: "tag", colorName: "blue", createdAt: from)
        context.insert(jar)
        for _ in 0..<205 {
            context.insert(
                MoneyTransaction(
                    id: UUID(), kind: .expense, amount: Decimal(string: "0.1")!,
                    occurredAt: from, note: "", accountID: account, categoryID: nil,
                    sourceRuleID: nil,
                    currencyCode: "VND", createdAt: from))
        }
        for (amount, currency, kind, date) in [
            (Decimal(30), "VND", TransactionKind.income, from),
            (Decimal(2), "USD", .expense, from), (Decimal(999), "VND", .expense, end),
        ] {
            context.insert(
                MoneyTransaction(
                    id: UUID(), kind: kind, amount: amount,
                    occurredAt: date, note: "", accountID: account, categoryID: nil,
                    sourceRuleID: nil,
                    currencyCode: currency, createdAt: from))
        }
        context.insert(
            AccountTransfer(
                id: UUID(), amount: 999, occurredAt: from, note: "",
                sourceAccountID: account, destinationAccountID: UUID(), currencyCode: "VND",
                createdAt: from))
        try context.save()
        var arguments: [String: MCPJSONValue] = [
            "dateFrom": .string(from.formatted(.iso8601)),
            "dateTo": .string(end.formatted(.iso8601)), "groupBy": .string("budgetJar"),
        ]
        let repository = MCPDataRepository(context: context)
        let query = try MCPQuery.parse(arguments: arguments, for: .summary)
        let result = try #require(repository.records(for: .summary, query: query).first)
        let totals = try #require(result.fields["totals"]?.arrayValue)
        let vnd = try #require(
            totals.first { $0.objectValue?["currencyCode"] == .string("VND") }?.objectValue)
        #expect(vnd["expense"] == .string("20.5"))
        #expect(vnd["income"] == .string("30"))
        #expect(vnd["net"] == .string("9.5"))
        #expect(vnd["transactionCount"] == .int(206))
        #expect(totals.count == 2)
        #expect(result.fields["expenseGroups"]?.arrayValue?.count == 2)
        #expect(
            result.fields["excludes"]
                == .array(["transfers", "savings", "investments"].map(MCPJSONValue.string)))
        var ungroupedArguments = arguments
        ungroupedArguments["groupBy"] = .string("none")
        let ungrouped = try #require(
            repository.records(
                for: .summary,
                query: MCPQuery.parse(arguments: ungroupedArguments, for: .summary)
            ).first)
        #expect(ungrouped.fields["expenseGroups"] == nil)
        arguments["accountID"] = .string(UUID().uuidString)
        let empty = try repository.records(
            for: .summary,
            query: MCPQuery.parse(arguments: arguments, for: .summary))
        #expect(empty.first?.fields["totals"] == .array([]))
        arguments.removeValue(forKey: "accountID")
        arguments["budgetJarID"] = .string(jar.id.uuidString)
        let jarResult = try repository.records(
            for: .summary,
            query: MCPQuery.parse(arguments: arguments, for: .summary))
        #expect(
            jarResult.first?.fields["totals"]?.arrayValue?.allSatisfy {
                $0.objectValue?["income"] == .string("0")
            } == true)
    }

    @Test("Defaults to 50, caps at 500, and rejects invalid limits")
    func limits() throws {
        #expect(try MCPQuery.parse(arguments: [:], for: .transactions).limit == 50)
        #expect(
            try MCPQuery.parse(arguments: ["limit": .int(500)], for: .transactions).limit == 500)
        #expect(throws: MCPArgumentError.self) {
            try MCPQuery.parse(arguments: ["limit": .int(501)], for: .transactions)
        }
        #expect(throws: MCPArgumentError.self) {
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
        do {
            _ = try MCPQuery.parse(
                arguments: ["dateFrom": .string("2026-09-01")], for: .transactions)
            Issue.record("Expected a field-specific date validation error")
        } catch let error as MCPArgumentError {
            #expect(error.field == "dateFrom")
            #expect(error.reason.contains("timezone"))
        }
        #expect(throws: MCPArgumentError.self) {
            try MCPQuery.parse(arguments: ["direction": .string("borrowed")], for: .transactions)
        }
        #expect(throws: MCPArgumentError.self) {
            try MCPQuery.parse(arguments: ["id": .string("not-a-uuid")], for: .transactions)
        }
        #expect(throws: MCPArgumentError.self) {
            try MCPQuery.parse(arguments: ["dateFrom": .string("yesterday")], for: .transactions)
        }
        #expect(throws: MCPArgumentError.self) {
            try MCPQuery.parse(arguments: ["accountID": .string("not-a-uuid")], for: .transactions)
        }
        #expect(throws: MCPArgumentError.self) {
            try MCPQuery.parse(arguments: ["kind": .string("refund")], for: .transactions)
        }
        #expect(throws: MCPArgumentError.self) {
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

    @MainActor
    @Test("Account balances and portfolio expose calculated values and reconciliation gaps")
    func financialAggregates() throws {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let account = CashAccount(
            id: UUID(), name: "TP Bank", kind: .normal, openingBalance: 100,
            currencyCode: "VND", createdAt: date)
        let instrument = FundInstrument(
            id: UUID(), symbol: "FUEVFVND", name: "VN Diamond", kind: .etf,
            currentPricePerUnit: 3, priceAsOf: date, currencyCode: "VND", createdAt: date)
        let jar = BudgetJar(
            id: UUID(), name: "Daily", allocationPercent: 100, role: .custom,
            symbolName: "tag", colorName: "blue", createdAt: date)
        let category = TransactionCategory(
            id: UUID(), name: "Transport", kind: .expense, symbolName: "car",
            colorName: "blue", createdAt: date, budgetJarID: jar.id)
        context.insert(account)
        context.insert(instrument)
        context.insert(jar)
        context.insert(category)
        context.insert(
            MoneyTransaction(
                id: UUID(), kind: .expense, amount: 10, occurredAt: date, note: "Xăng",
                accountID: account.id, categoryID: category.id, sourceRuleID: nil,
                currencyCode: "VND", createdAt: date))
        let snapshot = try IncomeAllocationSnapshotCodec.encode(
            IncomeAllocationSnapshot.capture(
                amount: 5, jars: [jar], capturedAt: date, isEstimated: false))
        context.insert(
            MoneyTransaction(
                id: UUID(), kind: .income, amount: 5, occurredAt: date, note: "Salary",
                accountID: account.id, categoryID: nil, sourceRuleID: nil,
                currencyCode: "VND", createdAt: date, incomeAllocationSnapshot: snapshot))
        context.insert(
            SavingsDeposit(
                id: UUID(), name: "Emergency", principal: 20, annualInterestRate: 5,
                termMonths: 6, openedAt: date, currencyCode: "VND", createdAt: date))
        context.insert(
            FundHolding(
                id: UUID(), instrumentID: instrument.id, units: 10, averageCostPerUnit: 2,
                createdAt: date))
        try context.save()

        let repository = MCPDataRepository(context: context)
        let balance = try #require(repository.records(for: .accountBalances).first)
        #expect(balance.fields["name"] == .string("TP Bank"))
        #expect(balance.fields["currentBalance"] == .string("95"))
        #expect(balance.fields["isReconciled"] == .bool(false))
        #expect(balance.fields["unattributedSavingsPrincipal"] == .string("20"))
        #expect(balance.fields["unattributedInvestmentCostBasis"] == .string("20"))

        let portfolio = try #require(repository.records(for: .portfolio).first)
        let totals = try #require(portfolio.fields["totals"]?.arrayValue?.first?.objectValue)
        #expect(totals["costBasis"] == .string("20"))
        #expect(totals["marketValue"] == .string("30"))
        #expect(totals["totalProfitLoss"] == .string("10"))
        #expect(portfolio.fields["unattributedSourceHoldingCount"] == .int(1))

        let noteQuery = try MCPQuery.parse(
            arguments: ["noteContains": .string("xĂ")], for: .transactions)
        let expense = try #require(
            MCPPaginator.page(
                records: repository.records(for: .transactions, query: noteQuery),
                query: noteQuery, tool: .transactions
            ).records.first)
        #expect(expense.fields["accountName"] == .string("TP Bank"))
        #expect(expense.fields["categoryName"] == .string("Transport"))
        #expect(expense.fields["jarName"] == .string("Daily"))

        let compactTransactions = try repository.records(for: .transactions)
        let compactSnapshot = try #require(
            compactTransactions.first { $0.fields["kind"] == .string("income") }?
                .fields["incomeAllocationSnapshot"]?.objectValue)
        #expect(compactSnapshot["jarCount"] == .int(1))
        #expect(compactSnapshot["allocationSlices"] == nil)
        let detailedQuery = try MCPQuery.parse(
            arguments: ["include": .array([.string("allocationSlices")])],
            for: .transactions)
        let detailedSnapshot = try #require(
            repository.records(for: .transactions, query: detailedQuery)
                .first { $0.fields["kind"] == .string("income") }?
                .fields["incomeAllocationSnapshot"]?.objectValue)
        #expect(detailedSnapshot["allocationSlices"]?.arrayValue?.count == 1)
    }
}
