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
}
