import Foundation
import Testing

@testable import MonMon

@Suite("Vietnamese transaction capture parser")
struct TransactionCaptureParserTests {
    private let now = Date(timeIntervalSince1970: 1_735_776_000)
    private let bankID = UUID(uuid: (16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let walletID = UUID(uuid: (16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    private let foodID = UUID(uuid: (32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let salaryID = UUID(uuid: (32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))

    private var context: TransactionCaptureContext {
        TransactionCaptureContext(
            accounts: [
                CaptureAccount(id: bankID, name: "TPBank", isCash: false),
                CaptureAccount(id: walletID, name: "Ví", isCash: true),
            ],
            categories: [
                CaptureCategory(
                    id: foodID,
                    name: "Ăn uống",
                    kind: .expense,
                    symbolName: "fork.knife"
                ),
                CaptureCategory(
                    id: salaryID,
                    name: "Lương",
                    kind: .income,
                    symbolName: "briefcase.fill"
                ),
            ],
            defaultAccountID: bankID,
            defaultExpenseCategoryID: foodID,
            defaultIncomeCategoryID: salaryID
        )
    }

    @Test("A compact expense uses defaults and keeps the useful note")
    func parsesCompactExpense() {
        let result = TransactionCaptureParser.parse(
            "50k ăn trưa",
            context: context,
            now: now
        )

        #expect(result.amount == 50_000)
        #expect(result.kind == .expense)
        #expect(result.occurredAt == now)
        #expect(result.accountID == bankID)
        #expect(result.categoryID == foodID)
        #expect(result.note == "ăn trưa")
        #expect(result.isReady)
    }

    @Test("Income, decimal millions, yesterday, account, and category are recognized")
    func parsesDetailedIncome() {
        let result = TransactionCaptureParser.parse(
            "thu 1,2 triệu lương TPBank hôm qua",
            context: context,
            now: now
        )

        #expect(result.amount == 1_200_000)
        #expect(result.kind == .income)
        #expect(result.occurredAt == Calendar.current.date(byAdding: .day, value: -1, to: now))
        #expect(result.accountID == bankID)
        #expect(result.categoryID == salaryID)
        #expect(result.isReady)
    }

    @Test("Cash aliases select the single cash account")
    func cashAliasSelectsWallet() {
        let result = TransactionCaptureParser.parse(
            "35 nghìn cafe tiền mặt",
            context: context,
            now: now
        )

        #expect(result.amount == 35_000)
        #expect(result.accountID == walletID)
        #expect(result.categoryID == foodID)
        #expect(result.note == "cafe")
        #expect(result.isReady)
    }

    @Test("Missing and multiple amounts require review")
    func uncertainAmountsRequireReview() {
        let missing = TransactionCaptureParser.parse(
            "ăn trưa tiền mặt",
            context: context,
            now: now
        )
        let multiple = TransactionCaptureParser.parse(
            "50k ăn trưa và 20k cafe",
            context: context,
            now: now
        )

        #expect(missing.issues.contains(.missingAmount))
        #expect(!missing.isReady)
        #expect(multiple.issues.contains(.multipleAmounts))
        #expect(!multiple.isReady)
    }

    @Test("Stale defaults never silently choose a different record")
    func staleDefaultsRequireReview() {
        var staleContext = context
        staleContext.defaultAccountID = UUID()
        staleContext.defaultExpenseCategoryID = UUID()

        let result = TransactionCaptureParser.parse(
            "80k mua đồ",
            context: staleContext,
            now: now
        )

        #expect(result.accountID == nil)
        #expect(result.categoryID == nil)
        #expect(result.issues.contains(.missingAccount))
        #expect(result.issues.contains(.missingCategory))
        #expect(!result.isReady)
    }
}
