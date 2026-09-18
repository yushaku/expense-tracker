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
    private let transportID = UUID(
        uuid: (32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))
    private let housingID = UUID(uuid: (32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4))
    private let shoppingID = UUID(
        uuid: (32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5))
    private let healthID = UUID(uuid: (32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6))
    private let entertainmentID = UUID(
        uuid: (32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7))
    private let bonusID = UUID(uuid: (32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8))
    private let interestID = UUID(
        uuid: (32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9))

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
                CaptureCategory(
                    id: transportID, name: "Di chuyển", kind: .expense,
                    symbolName: "car.fill"),
                CaptureCategory(
                    id: housingID, name: "Nhà ở", kind: .expense,
                    symbolName: "house.fill"),
                CaptureCategory(
                    id: shoppingID, name: "Mua sắm", kind: .expense,
                    symbolName: "cart.fill"),
                CaptureCategory(
                    id: healthID, name: "Sức khỏe", kind: .expense,
                    symbolName: "cross.case.fill"),
                CaptureCategory(
                    id: entertainmentID, name: "Giải trí", kind: .expense,
                    symbolName: "gamecontroller.fill"),
                CaptureCategory(
                    id: bonusID, name: "Thưởng", kind: .income,
                    symbolName: "gift.fill"),
                CaptureCategory(
                    id: interestID, name: "Tiền lãi", kind: .income,
                    symbolName: "building.columns.fill"),
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

    @Test(
        "Common Vietnamese phrases select a specific expense category instead of the default",
        arguments: [
            ("100k đổ xăng", "Transport"),
            ("850k tiền điện", "Housing"),
            ("300k mua quần áo", "Shopping"),
            ("120k khám nha khoa", "Health"),
            ("200k vé xem phim", "Entertainment"),
        ])
    func commonExpenseVocabulary(_ entry: String, _ category: String) {
        let expectedID: UUID =
            switch category {
            case "Transport": transportID
            case "Housing": housingID
            case "Shopping": shoppingID
            case "Health": healthID
            default: entertainmentID
            }

        let result = TransactionCaptureParser.parse(entry, context: context, now: now)

        #expect(result.categoryID == expectedID, "Unexpected category for: \(entry)")
        #expect(result.isReady, "Capture not ready for: \(entry); issues: \(result.issues)")
    }

    @Test(
        "Common Vietnamese income phrases select their own income categories",
        arguments: [
            ("nhận 2tr tiền thưởng", "Bonus"),
            ("tiền vào 150k lãi tiết kiệm", "Interest"),
        ])
    func commonIncomeVocabulary(_ entry: String, _ category: String) {
        let result = TransactionCaptureParser.parse(entry, context: context, now: now)

        #expect(result.kind == .income)
        #expect(result.categoryID == (category == "Bonus" ? bonusID : interestID))
        #expect(result.isReady)
    }

    @Test(
        "Vietnamese amounts written as words are recognized",
        arguments: [
            ("năm mươi nghìn cà phê", Decimal(50_000), "Food"),
            ("một triệu hai trăm nghìn tiền nhà", Decimal(1_200_000), "Housing"),
        ])
    func vietnameseWordAmounts(_ entry: String, _ amount: Decimal, _ category: String) {
        let result = TransactionCaptureParser.parse(entry, context: context, now: now)

        #expect(result.amount == amount)
        #expect(result.categoryID == (category == "Food" ? foodID : housingID))
        #expect(result.isReady, "Capture not ready for: \(entry); issues: \(result.issues)")
    }

    @Test(
        "Conversational relative dates are recognized",
        arguments: [
            ("200k vé xem phim tối qua", -1),
            ("100k đổ xăng hôm kia", -2),
        ])
    func conversationalRelativeDates(_ entry: String, _ dayOffset: Int) {
        let result = TransactionCaptureParser.parse(entry, context: context, now: now)

        #expect(
            result.occurredAt == Calendar.current.date(byAdding: .day, value: dayOffset, to: now))
        #expect(result.isReady)
    }

    @Test(
        "Words that only resemble income keywords after accent folding remain expenses",
        arguments: [
            ("100k mua lại quần áo", "Shopping"),
            ("200k đi chơi thứ hai", "Entertainment"),
        ])
    func foldedAccentCollisionsRemainExpenses(_ entry: String, _ category: String) {
        let result = TransactionCaptureParser.parse(entry, context: context, now: now)

        #expect(result.kind == .expense)
        #expect(result.categoryID == (category == "Shopping" ? shoppingID : entertainmentID))
        #expect(result.isReady, "Capture not ready for: \(entry); issues: \(result.issues)")
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
