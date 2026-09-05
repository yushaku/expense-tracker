import Foundation
import Testing

@testable import MonMon

@Suite("MCP record serialization")
struct MCPRecordSerializerTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000.125)
    private let id = UUID(
        uuid: (
            0xAA, 0xAA, 0xAA, 0xAA, 0xBB, 0xBB, 0xCC, 0xCC,
            0xDD, 0xDD, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE, 0xEE
        ))

    @Test("Serializes exact Decimal, UTC date, UUID, enum, and null values")
    func scalarEncoding() throws {
        let amount = try #require(Decimal(string: "1234567890.012300"))
        let transaction = MoneyTransaction(
            id: id,
            kind: .expense,
            amount: amount,
            occurredAt: date,
            note: "Lunch",
            accountID: id,
            categoryID: nil,
            sourceRuleID: nil,
            currencyCode: "VND",
            createdAt: date
        )

        let record = try MCPRecordSerializer.serialize(transaction)

        #expect(record.fields["id"] == .string(id.uuidString.lowercased()))
        #expect(record.fields["kind"] == .string("expense"))
        #expect(record.fields["amount"] == .string("1234567890.0123"))
        #expect(record.fields["occurredAt"] == .string("2023-11-14T22:13:20.125Z"))
        #expect(record.fields["categoryID"] == .null)
        #expect(record.fields["signedAmount"] == nil)
    }

    @Test("Decodes stored JSON snapshots without adding derived goal fields")
    func storedJSON() throws {
        let contribution = GoalContribution(id: id, amount: 25, occurredAt: date)
        let goal = FinancialGoal(
            id: id,
            name: "Emergency",
            targetAmount: 100,
            earmarkedAmount: 25,
            targetDate: date,
            monthlyContribution: 10,
            fundingJarID: nil,
            symbolName: "tag.fill",
            colorName: "green",
            createdAt: date,
            contributionHistoryData: try JSONEncoder().encode([contribution])
        )

        let record = try MCPRecordSerializer.serialize(goal)
        let history = record.fields["contributionHistoryData"]?.arrayValue

        #expect(history?.count == 1)
        #expect(history?.first?.objectValue?["amount"] == .string("25"))
        #expect(record.fields["progress"] == nil)
        #expect(record.fields["remainingAmount"] == nil)
    }

    @Test("Reports invalid stored JSON as a safe decode error")
    func invalidStoredJSON() {
        let goal = FinancialGoal(
            id: id,
            name: "Emergency",
            targetAmount: 100,
            earmarkedAmount: 0,
            targetDate: date,
            monthlyContribution: 10,
            fundingJarID: nil,
            symbolName: "tag.fill",
            colorName: "green",
            createdAt: date,
            contributionHistoryData: Data("not-json".utf8)
        )

        #expect(throws: MCPToolError.decodeFailed) {
            try MCPRecordSerializer.serialize(goal)
        }
    }

    @Test("Every model exposes all and only stored fields plus its discriminator")
    func completeModelContracts() throws {
        let records: [(MCPRecord, Set<String>)] = try [
            (
                MCPRecordSerializer.serialize(
                    CashAccount(
                        id: id, name: "Cash", kind: .normal, openingBalance: 1,
                        currencyCode: "VND", createdAt: date
                    )),
                [
                    "recordType", "id", "name", "kind", "openingBalance", "creditLimit",
                    "currencyCode", "createdAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    MoneyTransaction(
                        id: id, kind: .expense, amount: 1, occurredAt: date, note: "",
                        accountID: id, categoryID: nil, sourceRuleID: nil, currencyCode: "VND",
                        createdAt: date
                    )),
                [
                    "recordType", "id", "kind", "amount", "occurredAt", "note", "accountID",
                    "categoryID", "sourceRuleID", "currencyCode", "createdAt", "sourceImportID",
                    "incomeAllocationSnapshot", "tripWorkspaceID", "budgetJarOverrideID",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    AccountTransfer(
                        id: id, amount: 1, occurredAt: date, note: "", sourceAccountID: id,
                        destinationAccountID: UUID(), currencyCode: "VND", createdAt: date
                    )),
                [
                    "recordType", "id", "amount", "occurredAt", "note", "sourceAccountID",
                    "destinationAccountID", "currencyCode", "createdAt", "sourceAccountImportID",
                    "destinationAccountImportID",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    TransactionCategory(
                        id: id, name: "Food", kind: .expense, symbolName: "tag.fill",
                        colorName: "green", createdAt: date
                    )),
                [
                    "recordType", "id", "name", "kind", "symbolName", "colorName", "budgetJarID",
                    "createdAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    RecurringRule(
                        id: id, kind: .expense, amount: 1, note: "Rent", accountID: id,
                        categoryID: nil, currencyCode: "VND", frequency: .monthly, interval: 1,
                        anchorDate: date, endDate: nil, isPaused: false, lastGeneratedAt: nil,
                        createdAt: date
                    )),
                [
                    "recordType", "id", "kind", "amount", "note", "accountID", "categoryID",
                    "currencyCode", "frequency", "interval", "anchorDate", "endDate", "isPaused",
                    "lastGeneratedAt", "createdAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    BudgetJar(
                        id: id, name: "Needs", allocationPercent: 50, role: .custom,
                        symbolName: "tag.fill", colorName: "green", createdAt: date
                    )),
                [
                    "recordType", "id", "name", "allocationPercent", "role", "symbolName",
                    "colorName", "createdAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    FinancialGoal(
                        id: id, name: "Goal", targetAmount: 1, earmarkedAmount: 0,
                        targetDate: date, monthlyContribution: 0, fundingJarID: nil,
                        symbolName: "tag.fill", colorName: "green", createdAt: date
                    )),
                [
                    "recordType", "id", "name", "targetAmount", "earmarkedAmount", "targetDate",
                    "monthlyContribution", "fundingJarID", "symbolName", "colorName", "createdAt",
                    "contributionHistoryData", "archivedAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    TripWorkspace(
                        id: id, sourceGoalID: nil, name: "Trip", budgetAmount: 1,
                        fundingJarID: nil, symbolName: "tag.fill", colorName: "green",
                        status: .active, startedAt: date, completedAt: nil, createdAt: date
                    )),
                [
                    "recordType", "id", "sourceGoalID", "name", "budgetAmount", "fundingJarID",
                    "symbolName", "colorName", "status", "startedAt", "completedAt", "createdAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    SavingsDeposit(
                        id: id, name: "Deposit", principal: 1, annualInterestRate: 2,
                        termMonths: 3, openedAt: date, currencyCode: "VND", createdAt: date
                    )),
                [
                    "recordType", "id", "name", "principal", "annualInterestRate", "termMonths",
                    "openedAt", "currencyCode", "createdAt", "sourceAccountID",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    SavingsWithdrawal(
                        id: id, depositID: nil, principal: 1, amountReceived: 1,
                        destinationAccountID: id, withdrawnAt: date, currencyCode: "VND",
                        createdAt: date
                    )),
                [
                    "recordType", "id", "depositID", "principal", "amountReceived",
                    "destinationAccountID", "withdrawnAt", "note", "currencyCode", "createdAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    FundInstrument(
                        id: id, symbol: "AAA", name: "Fund", kind: .fund,
                        currentPricePerUnit: 1, priceAsOf: date, currencyCode: "VND",
                        createdAt: date
                    )),
                [
                    "recordType", "id", "symbol", "name", "kind", "currentPricePerUnit",
                    "askPricePerUnit", "priceAsOf", "priceSource", "priceFetchedAt",
                    "autoQuoteEnabled", "logoURL", "currencyCode", "createdAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    FundHolding(
                        id: id, instrumentID: nil, units: 1, averageCostPerUnit: 1,
                        createdAt: date
                    )),
                [
                    "recordType", "id", "instrumentID", "units", "averageCostPerUnit",
                    "sourceAccountID", "createdAt", "purchasedAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    FundSale(
                        id: id, holdingID: nil, units: 1, pricePerUnit: 1,
                        proceedsAccountID: id, soldAt: date, currencyCode: "VND", createdAt: date
                    )),
                [
                    "recordType", "id", "holdingID", "units", "pricePerUnit", "proceedsAccountID",
                    "soldAt", "note", "currencyCode", "createdAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    Debt(
                        id: id, counterparty: "A", direction: .borrowed, principal: 1,
                        annualInterestRate: 0, openedAt: date, dueDate: nil, accountID: nil,
                        note: "", currencyCode: "VND", createdAt: date
                    )),
                [
                    "recordType", "id", "counterparty", "direction", "principal",
                    "annualInterestRate", "openedAt", "dueDate", "accountID", "note",
                    "currencyCode", "createdAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    DebtPayment(
                        id: id, debtID: nil, amount: 1, occurredAt: date, accountID: id,
                        note: "", currencyCode: "VND", createdAt: date
                    )),
                [
                    "recordType", "id", "debtID", "amount", "occurredAt", "accountID", "note",
                    "currencyCode", "createdAt",
                ]
            ),
            (
                MCPRecordSerializer.serialize(
                    PendingTransactionCapture(
                        id: id, rawText: "50k lunch", kind: .expense, amount: 50_000,
                        occurredAt: date, note: "lunch", accountID: nil, categoryID: nil,
                        issueCodes: "missingAccount", createdAt: date
                    )),
                [
                    "recordType", "id", "rawText", "kind", "amount", "occurredAt", "note",
                    "accountID", "categoryID", "issueCodes", "createdAt",
                ]
            ),
        ]

        for (record, expectedKeys) in records {
            #expect(Set(record.fields.keys) == expectedKeys)
        }
    }
}
