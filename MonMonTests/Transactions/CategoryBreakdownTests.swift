import Foundation
import Testing

@testable import MonMon

@Suite("Category breakdown")
struct CategoryBreakdownTests {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let accountID = UUID()

    private func makeCategory(
        name: String,
        kind: TransactionKind,
        symbolName: String = "fork.knife",
        colorName: String = "peach"
    ) -> TransactionCategory {
        TransactionCategory(
            id: UUID(),
            name: name,
            kind: kind,
            symbolName: symbolName,
            colorName: colorName,
            createdAt: fixedDate
        )
    }

    private func makeTransaction(
        kind: TransactionKind,
        amount: Decimal,
        categoryID: UUID?,
        dayOffset: TimeInterval = 0
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: kind,
            amount: amount,
            occurredAt: fixedDate.addingTimeInterval(dayOffset * 86_400),
            note: "",
            accountID: accountID,
            categoryID: categoryID,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: fixedDate
        )
    }

    @Test("Nothing recorded produces no wedges")
    func emptyInputHasNoSlices() {
        let slices = CategoryBreakdown.slices(of: .expense, transactions: [], categories: [])

        #expect(slices.isEmpty)
        #expect(CategoryBreakdown.total(of: slices) == 0)
    }

    @Test("Transactions are grouped and totalled per category, largest first")
    func groupsByCategory() {
        let food = makeCategory(name: "Food", kind: .expense)
        let transport = makeCategory(name: "Transport", kind: .expense)
        let transactions = [
            makeTransaction(kind: .expense, amount: 100_000, categoryID: food.id),
            makeTransaction(kind: .expense, amount: 250_000, categoryID: food.id),
            makeTransaction(kind: .expense, amount: 300_000, categoryID: transport.id),
        ]

        let slices = CategoryBreakdown.slices(
            of: .expense,
            transactions: transactions,
            categories: [food, transport]
        )

        #expect(slices.map(\.name) == ["Food", "Transport"])
        #expect(slices.map(\.amount) == [350_000, 300_000])
        #expect(slices.map(\.count) == [2, 1])
        #expect(CategoryBreakdown.total(of: slices) == 650_000)
    }

    @Test("The other direction is left out")
    func theOtherDirectionIsExcluded() {
        let food = makeCategory(name: "Food", kind: .expense)
        let salary = makeCategory(name: "Salary", kind: .income)
        let transactions = [
            makeTransaction(kind: .expense, amount: 100_000, categoryID: food.id),
            makeTransaction(kind: .income, amount: 9_000_000, categoryID: salary.id),
        ]
        let categories = [food, salary]

        let expenses = CategoryBreakdown.slices(
            of: .expense,
            transactions: transactions,
            categories: categories
        )
        let income = CategoryBreakdown.slices(
            of: .income,
            transactions: transactions,
            categories: categories
        )

        #expect(expenses.map(\.name) == ["Food"])
        #expect(income.map(\.name) == ["Salary"])
    }

    @Test("Transactions whose category is gone are still counted")
    func orphanedTransactionsAreKept() {
        let transactions = [
            makeTransaction(kind: .expense, amount: 100_000, categoryID: nil),
            makeTransaction(kind: .expense, amount: 50_000, categoryID: nil),
        ]

        let slices = CategoryBreakdown.slices(
            of: .expense,
            transactions: transactions,
            categories: []
        )

        #expect(slices.count == 1)
        #expect(slices.first?.name == CategoryBreakdown.uncategorizedName)
        #expect(slices.first?.categoryID == nil)
        #expect(slices.first?.amount == 150_000)
    }

    @Test("A category deleted after the fact falls back to a renderable style")
    func missingCategoryFallsBackToADefaultStyle() {
        let slices = CategoryBreakdown.slices(
            of: .expense,
            transactions: [makeTransaction(kind: .expense, amount: 1_000, categoryID: UUID())],
            categories: []
        )

        #expect(slices.first?.symbolName == CategoryPalette.defaultSymbolName)
        #expect(slices.first?.colorName == CategoryPalette.defaultColorName)
    }

    @Test("Equal amounts order by name, so a redraw never reshuffles them")
    func tiesOrderByName() {
        let books = makeCategory(name: "Books", kind: .expense)
        let apples = makeCategory(name: "Apples", kind: .expense)
        let transactions = [
            makeTransaction(kind: .expense, amount: 100_000, categoryID: books.id),
            makeTransaction(kind: .expense, amount: 100_000, categoryID: apples.id),
        ]

        let slices = CategoryBreakdown.slices(
            of: .expense,
            transactions: transactions,
            categories: [books, apples]
        )

        #expect(slices.map(\.name) == ["Apples", "Books"])
    }

    @Test("Drilling into a wedge returns its transactions, newest first")
    func drillDownReturnsNewestFirst() {
        let food = makeCategory(name: "Food", kind: .expense)
        let older = makeTransaction(
            kind: .expense,
            amount: 100_000,
            categoryID: food.id,
            dayOffset: 0
        )
        let newer = makeTransaction(
            kind: .expense,
            amount: 200_000,
            categoryID: food.id,
            dayOffset: 3
        )
        let other = makeTransaction(kind: .expense, amount: 50_000, categoryID: UUID())

        let matching = CategoryBreakdown.transactions(
            for: food.id,
            of: .expense,
            in: [older, newer, other]
        )

        #expect(matching.map(\.id) == [newer.id, older.id])
    }

    @Test("Shares are the same rounding every other chart uses")
    func sharesMatchThePercentageHelper() {
        #expect(Percentage.share(of: 1, in: 3) == Decimal(string: "33.3"))
        #expect(Percentage.share(of: 25, in: 100) == 25)
        #expect(Percentage.share(of: 5, in: 0) == 0)
    }
}
