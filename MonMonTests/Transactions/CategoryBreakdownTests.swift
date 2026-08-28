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

    private func makeSlice(_ name: String, _ amount: Decimal) -> CategoryBreakdownSlice {
        CategoryBreakdownSlice(
            categoryID: UUID(),
            name: name,
            symbolName: "fork.knife",
            colorName: "peach",
            amount: amount,
            count: 1
        )
    }

    @Test("A turn round the doughnut lands on the wedge covering it")
    func turnPicksTheWedgeUnderIt() {
        // A half, then two quarters, so the boundaries fall on easy fractions.
        let slices = [makeSlice("Food", 500), makeSlice("Rent", 250), makeSlice("Fun", 250)]

        #expect(CategoryBreakdown.slice(atTurn: 0, in: slices)?.name == "Food")
        #expect(CategoryBreakdown.slice(atTurn: 0.49, in: slices)?.name == "Food")
        #expect(CategoryBreakdown.slice(atTurn: 0.5, in: slices)?.name == "Rent")
        #expect(CategoryBreakdown.slice(atTurn: 0.74, in: slices)?.name == "Rent")
        #expect(CategoryBreakdown.slice(atTurn: 0.75, in: slices)?.name == "Fun")
        #expect(CategoryBreakdown.slice(atTurn: 0.999, in: slices)?.name == "Fun")
    }

    @Test("A turn outside one lap belongs to no wedge")
    func turnOutsideOneLapPicksNothing() {
        let slices = [makeSlice("Food", 500)]

        #expect(CategoryBreakdown.slice(atTurn: -0.1, in: slices) == nil)
        #expect(CategoryBreakdown.slice(atTurn: 1, in: slices) == nil)
    }

    @Test("An empty doughnut has no wedge to land on")
    func turnOnAnEmptyDoughnutPicksNothing() {
        #expect(CategoryBreakdown.slice(atTurn: 0.5, in: []) == nil)
        #expect(CategoryBreakdown.slice(atTurn: 0.5, in: [makeSlice("Food", 0)]) == nil)
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

    @Test("Waterfall subtracts expense categories from income in descending order")
    func waterfallBuildsRunningBalances() {
        let food = makeCategory(name: "Food", kind: .expense, colorName: "peach")
        let rent = makeCategory(name: "Rent", kind: .expense, colorName: "blue")
        let salary = makeCategory(name: "Salary", kind: .income)
        let summary = CategoryWaterfall.summary(
            transactions: [
                makeTransaction(kind: .income, amount: 10_000, categoryID: salary.id),
                makeTransaction(kind: .expense, amount: 4_000, categoryID: rent.id),
                makeTransaction(kind: .expense, amount: 2_500, categoryID: food.id),
                makeTransaction(kind: .expense, amount: 500, categoryID: food.id),
            ],
            categories: [food, rent, salary]
        )

        #expect(summary.income == 10_000)
        #expect(summary.totalExpense == 7_000)
        #expect(summary.netSavings == 3_000)
        #expect(summary.savingsRate == 30)
        #expect(summary.steps.map(\.name) == ["Income", "Rent", "Food", "Net savings"])
        #expect(summary.steps.map(\.start) == [0, 10_000, 6_000, 0])
        #expect(summary.steps.map(\.end) == [10_000, 6_000, 3_000, 3_000])
    }

    @Test("Waterfall keeps six categories and combines the rest as Other")
    func waterfallCombinesTailCategories() {
        let categories = (1...8).map { index in
            makeCategory(name: "Category \(index)", kind: .expense)
        }
        let transactions = categories.enumerated().map { index, category in
            makeTransaction(
                kind: .expense,
                amount: Decimal(8 - index) * 100,
                categoryID: category.id
            )
        }
        let summary = CategoryWaterfall.summary(
            transactions: transactions,
            categories: categories
        )

        #expect(
            summary.steps.map(\.name)
                == [
                    "Income", "Category 1", "Category 2", "Category 3", "Category 4",
                    "Category 5", "Category 6", "Other", "Net savings",
                ]
        )
        #expect(summary.steps.first { $0.kind == .other }?.amount == 300)
        #expect(summary.netSavings == -3_600)
        #expect(summary.savingsRate == nil)
    }

    @Test("Waterfall keeps a negative savings rate instead of clamping it")
    func waterfallReportsDeficitRate() {
        let food = makeCategory(name: "Food", kind: .expense)
        let summary = CategoryWaterfall.summary(
            transactions: [
                makeTransaction(kind: .income, amount: 1_000, categoryID: nil),
                makeTransaction(kind: .expense, amount: 1_250, categoryID: food.id),
            ],
            categories: [food]
        )

        #expect(summary.netSavings == -250)
        #expect(summary.savingsRate == -25)
        #expect(summary.steps.last?.start == 0)
        #expect(summary.steps.last?.end == -250)
    }

    @Test("Waterfall uses stable alphabetical ordering for equal expenses")
    func waterfallOrdersEqualExpensesByName() {
        let books = makeCategory(name: "Books", kind: .expense)
        let apples = makeCategory(name: "Apples", kind: .expense)
        let summary = CategoryWaterfall.summary(
            transactions: [
                makeTransaction(kind: .expense, amount: 500, categoryID: books.id),
                makeTransaction(kind: .expense, amount: 500, categoryID: apples.id),
            ],
            categories: [books, apples]
        )

        #expect(summary.steps.map(\.name) == ["Income", "Apples", "Books", "Net savings"])
    }
}
