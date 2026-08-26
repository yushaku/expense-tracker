import Foundation

/// What a transaction screen is asking of the ledger: some words to look for, a
/// slice of time, a direction, and the categories and accounts worth keeping.
///
/// An empty set means "every one of them" rather than "none": a filter the owner
/// has not touched narrows nothing. A screen can use the same query for every
/// transaction-backed section, so its figures and rows stay in sync.
struct TransactionQuery: Equatable {
    var text: String = ""
    var range: TransactionRange
    var filter: TransactionListFilter = .all
    var categoryIDs: Set<UUID> = []
    var accountIDs: Set<UUID> = []

    init(range: TransactionRange) {
        self.range = range
    }

    /// Whether anything beyond the period is narrowing the results, which is
    /// what the screen offers a "clear" button for.
    var isNarrowed: Bool {
        hasSearchText || hasStructuredFilters
    }

    var hasSearchText: Bool {
        !trimmedText.isEmpty
    }

    var hasStructuredFilters: Bool {
        filter != .all || !categoryIDs.isEmpty || !accountIDs.isEmpty
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Runs a `TransactionQuery` over the ledger.
///
/// Nothing here draws or reads the clock, so the same query gives the same
/// results in a test as on screen. Names are handed in rather than looked up:
/// searching for a category by name is the screen's job to make possible, not
/// this type's job to know how.
enum TransactionSearch {
    /// The transactions a query keeps, newest first when handed a list already
    /// in that order.
    static func results(
        of query: TransactionQuery,
        transactions: [MoneyTransaction],
        categoryNames: [UUID: String] = [:],
        accountNames: [UUID: String] = [:]
    ) -> [MoneyTransaction] {
        let terms = self.terms(of: query.trimmedText)

        return transactions.filter { transaction in
            guard query.range.contains(transaction.occurredAt) else {
                return false
            }

            if let kind = query.filter.kind, transaction.kind != kind {
                return false
            }

            if !query.categoryIDs.isEmpty {
                guard let categoryID = transaction.categoryID,
                    query.categoryIDs.contains(categoryID)
                else {
                    return false
                }
            }

            if !query.accountIDs.isEmpty, !query.accountIDs.contains(transaction.accountID) {
                return false
            }

            guard !terms.isEmpty else {
                return true
            }

            let haystack = self.haystack(
                for: transaction,
                categoryNames: categoryNames,
                accountNames: accountNames
            )

            // Every word has to land somewhere, so typing more words narrows
            // the results rather than widening them.
            return terms.allSatisfy { term in
                matches(term, in: haystack, amount: transaction.amount)
            }
        }
    }

    /// The words a search field was asked for, folded so accents and case never
    /// decide whether a Vietnamese note is found.
    static func terms(of text: String) -> [String] {
        fold(text)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    /// Everything about a transaction a word can be found in: what the owner
    /// wrote, what it was filed under, and where the money moved.
    private static func haystack(
        for transaction: MoneyTransaction,
        categoryNames: [UUID: String],
        accountNames: [UUID: String]
    ) -> String {
        var parts = [transaction.note]

        if let categoryID = transaction.categoryID, let name = categoryNames[categoryID] {
            parts.append(name)
        }

        if let name = accountNames[transaction.accountID] {
            parts.append(name)
        }

        return fold(parts.joined(separator: " "))
    }

    /// A word matches either the words on a transaction or, when it is digits,
    /// the digits of its amount. Typing `150` finds 150,000 without the owner
    /// having to know how the figure is punctuated.
    private static func matches(_ term: String, in haystack: String, amount: Decimal) -> Bool {
        if haystack.contains(term) {
            return true
        }

        let digits = term.filter(\.isNumber)

        guard !digits.isEmpty, digits.count == term.count else {
            return false
        }

        return amountDigits(of: amount).contains(digits)
    }

    /// The amount as bare digits, which is what a typed figure is compared
    /// against. Fractions are dropped: money here is whole đồng.
    private static func amountDigits(of amount: Decimal) -> String {
        var rounded = Decimal()
        var value = amount

        NSDecimalRound(&rounded, &value, 0, .plain)

        return NSDecimalNumber(decimal: rounded).stringValue.filter(\.isNumber)
    }

    /// Lowercased and stripped of accents, so `an` finds `Ăn uống`.
    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
