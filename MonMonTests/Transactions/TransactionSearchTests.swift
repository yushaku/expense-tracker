import Foundation
import Testing

@testable import MonMon

@Suite("Transaction search")
struct TransactionSearchTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let accountID = UUID()
    private let categoryID = UUID()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return TransactionPeriod.calendar.date(from: components) ?? .distantPast
    }

    private func makeTransaction(
        kind: TransactionKind = .expense,
        amount: Decimal = 100_000,
        note: String = "",
        occurredAt: Date? = nil,
        accountID: UUID? = nil,
        categoryID: UUID? = nil
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: kind,
            amount: amount,
            occurredAt: occurredAt ?? date(2026, 1, 15),
            note: note,
            accountID: accountID ?? self.accountID,
            categoryID: categoryID,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
    }

    private var januaryQuery: TransactionQuery {
        TransactionQuery(range: .month(containing: date(2026, 1, 15)))
    }

    @Test("A query with nothing typed keeps the period it was given")
    func emptyQueryKeepsThePeriod() {
        let inside = makeTransaction(occurredAt: date(2026, 1, 2))
        let outside = makeTransaction(occurredAt: date(2026, 2, 2))

        let results = TransactionSearch.results(
            of: januaryQuery,
            transactions: [inside, outside]
        )

        #expect(results.map(\.id) == [inside.id])
    }

    @Test("A word is looked for in the note, the category, and the account")
    func textMatchesNoteCategoryAndAccount() {
        let byNote = makeTransaction(note: "Coffee with Mai")
        let byCategory = makeTransaction(categoryID: categoryID)
        let byAccount = makeTransaction(accountID: accountID)
        let unrelated = makeTransaction(note: "Taxi")

        func search(_ text: String) -> [UUID] {
            var query = januaryQuery
            query.text = text

            return TransactionSearch.results(
                of: query,
                transactions: [byNote, byCategory, byAccount, unrelated],
                categoryNames: [categoryID: "Eating out"],
                accountNames: [accountID: "Techcombank"]
            )
            .map(\.id)
        }

        #expect(search("coffee") == [byNote.id])
        #expect(search("eating") == [byCategory.id])
        #expect(search("techcombank").count == 4)
        #expect(search("nothing").isEmpty)
    }

    @Test("Accents and case never decide whether a note is found")
    func textIgnoresAccentsAndCase() {
        let transaction = makeTransaction(note: "Ăn uống")
        var query = januaryQuery
        query.text = "AN UONG"

        let results = TransactionSearch.results(of: query, transactions: [transaction])

        #expect(results.map(\.id) == [transaction.id])
    }

    @Test("Every word typed has to land somewhere")
    func everyTermMustMatch() {
        let transaction = makeTransaction(note: "Coffee with Mai")
        var query = januaryQuery

        query.text = "coffee mai"
        #expect(TransactionSearch.results(of: query, transactions: [transaction]).count == 1)

        query.text = "coffee taxi"
        #expect(TransactionSearch.results(of: query, transactions: [transaction]).isEmpty)
    }

    @Test("Digits are looked for in the amount, punctuation and all")
    func digitsMatchTheAmount() {
        let transaction = makeTransaction(amount: 150_000, note: "Lunch")
        var query = januaryQuery

        query.text = "150"
        #expect(TransactionSearch.results(of: query, transactions: [transaction]).count == 1)

        query.text = "150000"
        #expect(TransactionSearch.results(of: query, transactions: [transaction]).count == 1)

        query.text = "999"
        #expect(TransactionSearch.results(of: query, transactions: [transaction]).isEmpty)
    }

    @Test("A direction, a category, and an account each narrow the results")
    func filtersNarrowTheResults() {
        let otherCategory = UUID()
        let otherAccount = UUID()
        let salary = makeTransaction(kind: .income, amount: 5_000_000, categoryID: categoryID)
        let lunch = makeTransaction(categoryID: otherCategory)
        let elsewhere = makeTransaction(accountID: otherAccount)
        let transactions = [salary, lunch, elsewhere]

        var byKind = januaryQuery
        byKind.filter = .income
        #expect(
            TransactionSearch.results(of: byKind, transactions: transactions).map(\.id)
                == [salary.id]
        )

        var byCategory = januaryQuery
        byCategory.categoryIDs = [otherCategory]
        #expect(
            TransactionSearch.results(of: byCategory, transactions: transactions).map(\.id)
                == [lunch.id]
        )

        var byAccount = januaryQuery
        byAccount.accountIDs = [otherAccount]
        #expect(
            TransactionSearch.results(of: byAccount, transactions: transactions).map(\.id)
                == [elsewhere.id]
        )
    }

    @Test("A category filter leaves out what was never filed")
    func categoryFilterExcludesUncategorized() {
        let filed = makeTransaction(categoryID: categoryID)
        let unfiled = makeTransaction()

        var query = januaryQuery
        query.categoryIDs = [categoryID]

        let results = TransactionSearch.results(of: query, transactions: [filed, unfiled])

        #expect(results.map(\.id) == [filed.id])
    }

    @Test("A query is narrowed only by what sits beyond its period")
    func narrowingIsAboutMoreThanThePeriod() {
        var query = januaryQuery
        #expect(!query.isNarrowed)

        query.text = "  "
        #expect(!query.isNarrowed)

        query.text = "coffee"
        #expect(query.isNarrowed)
    }

    @Test("Search text reports its state separately from structured filters")
    func searchStateIsSeparate() {
        var query = januaryQuery
        #expect(!query.hasSearchText)
        #expect(!query.hasStructuredFilters)

        query.text = "  coffee  "

        #expect(query.hasSearchText)
        #expect(!query.hasStructuredFilters)
        #expect(query.isNarrowed)
    }

    @Test("Direction, category, and account filters report structured state")
    func structuredFilterState() {
        var byDirection = januaryQuery
        byDirection.filter = .income

        var byCategory = januaryQuery
        byCategory.categoryIDs = [UUID()]

        var byAccount = januaryQuery
        byAccount.accountIDs = [UUID()]

        #expect(byDirection.hasStructuredFilters)
        #expect(byCategory.hasStructuredFilters)
        #expect(byAccount.hasStructuredFilters)
        #expect(!byDirection.hasSearchText)
    }

    @Test("Every report projection uses the global query results")
    func everyReportProjectionUsesTheGlobalQuery() {
        let account = CashAccount(
            id: accountID,
            name: "Wallet",
            kind: .normal,
            openingBalance: 0,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
        let category = TransactionCategory(
            id: categoryID,
            name: "Food",
            kind: .expense,
            symbolName: "fork.knife",
            colorName: "peach",
            createdAt: createdAt
        )
        let included = makeTransaction(
            amount: 125_000,
            note: "Coffee",
            categoryID: categoryID
        )
        let transactions = [
            included,
            makeTransaction(kind: .income, note: "Coffee", categoryID: categoryID),
            makeTransaction(note: "Lunch", categoryID: categoryID),
            makeTransaction(note: "Coffee", accountID: UUID(), categoryID: categoryID),
            makeTransaction(note: "Coffee", categoryID: UUID()),
            makeTransaction(note: "Coffee", occurredAt: date(2026, 2, 1), categoryID: categoryID),
        ]
        var query = januaryQuery
        query.text = "coffee"
        query.filter = .expense
        query.categoryIDs = [categoryID]
        query.accountIDs = [accountID]

        let report = ReportData(
            query: query,
            transactions: transactions,
            categoryNames: [categoryID: category.name],
            accountNames: [accountID: account.name]
        )

        #expect(report.transactions.map(\.id) == [included.id])
        #expect(report.income == 0)
        #expect(report.expense == 125_000)
        #expect(report.count == 1)
        #expect(
            TransactionCalendar.monthTotals(of: report.calendarWeeks(of: date(2026, 1, 1)))
                .expense == 125_000
        )
        #expect(
            report.accountSpendingRows(accounts: [account])
                == [AccountSpendingRow(accountID: accountID, amount: 125_000, count: 1)]
        )
        #expect(report.categoryBreakdownSlices(of: .income, categories: [category]).count == 1)
        #expect(report.netTrend.map(\.net) == [-125_000])
    }

    @Test("Report shows transaction rows only while searching")
    func reportTransactionListVisibility() {
        var query = januaryQuery

        #expect(ReportContentVisibility(query: query).showsNetTrend)
        #expect(!ReportContentVisibility(query: query).showsTransactionList)

        query.filter = .income

        #expect(ReportContentVisibility(query: query).showsNetTrend)
        #expect(!ReportContentVisibility(query: query).showsTransactionList)

        query.text = "salary"

        #expect(!ReportContentVisibility(query: query).showsNetTrend)
        #expect(ReportContentVisibility(query: query).showsTransactionList)
    }

    @Test("The report calendar shows only while the filter is one month")
    func calendarFollowsTheFilterScope() {
        var query = januaryQuery

        query.range = .month(containing: date(2026, 1, 15))
        #expect(ReportContentVisibility(query: query).showsCalendar)

        query.range = .year(containing: date(2026, 1, 15))
        #expect(!ReportContentVisibility(query: query).showsCalendar)

        query.range = .day(containing: date(2026, 1, 15))
        #expect(!ReportContentVisibility(query: query).showsCalendar)

        query.range = .custom(from: date(2026, 1, 2), to: date(2026, 3, 4))
        #expect(!ReportContentVisibility(query: query).showsCalendar)
    }
}
