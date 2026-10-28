import Foundation
import SwiftData

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

    /// Both ends participate in account and text searches. A category or an
    /// income/expense filter excludes transfers, which have neither attribute.
    static func transferResults(
        of query: TransactionQuery,
        transfers: [AccountTransfer],
        accountNames: [UUID: String] = [:]
    ) -> [AccountTransfer] {
        guard query.filter == .all, query.categoryIDs.isEmpty else { return [] }
        let terms = terms(of: query.trimmedText)
        return transfers.filter { transfer in
            guard query.range.contains(transfer.occurredAt) else { return false }
            if !query.accountIDs.isEmpty,
                !query.accountIDs.contains(transfer.sourceAccountID),
                !query.accountIDs.contains(transfer.destinationAccountID)
            {
                return false
            }
            let haystack = fold(
                [
                    transfer.note,
                    accountNames[transfer.sourceAccountID] ?? "",
                    accountNames[transfer.destinationAccountID] ?? "",
                    "Transfer Internal transfer Chuyển tiền Chuyển khoản",
                ].joined(separator: " "))
            return terms.allSatisfy { matches($0, in: haystack, amount: transfer.amount) }
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

/// Fetches cut to a period in the store rather than in memory.
///
/// A screen that only ever shows one period used to fetch the whole ledger and
/// filter it on every update, which with a few thousand rows is most of the
/// work behind a hitch. These descriptors keep the same newest-first order as
/// the unfiltered queries they replace, so `TransactionSearch` sees the rows
/// it saw before, minus the ones its range test would have dropped anyway.
enum LedgerFetch {
    static func transactions(in range: TransactionRange) -> FetchDescriptor<MoneyTransaction> {
        let start = range.start
        let end = range.end
        return FetchDescriptor(
            predicate: #Predicate { $0.occurredAt >= start && $0.occurredAt < end },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
    }

    static func transfers(in range: TransactionRange) -> FetchDescriptor<AccountTransfer> {
        let start = range.start
        let end = range.end
        return FetchDescriptor(
            predicate: #Predicate { $0.occurredAt >= start && $0.occurredAt < end },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
    }

    /// Every expense linked to one trip, newest first.
    static func tripTransactions(_ workspaceID: UUID) -> FetchDescriptor<MoneyTransaction> {
        let id: UUID? = workspaceID
        return FetchDescriptor(
            predicate: #Predicate { $0.tripWorkspaceID == id },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
    }

    /// Every transaction booked against one account, newest first.
    static func transactions(inAccount accountID: UUID) -> FetchDescriptor<MoneyTransaction> {
        FetchDescriptor(
            predicate: #Predicate { $0.accountID == accountID },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
    }

    /// Every transfer with one account at either end, newest first.
    static func transfers(touching accountID: UUID) -> FetchDescriptor<AccountTransfer> {
        FetchDescriptor(
            predicate: #Predicate {
                $0.sourceAccountID == accountID || $0.destinationAccountID == accountID
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
    }

    /// The transactions filed under one category, newest first. Without a
    /// category, as when one is still being added, nothing is filed under it.
    static func transactions(inCategory categoryID: UUID?) -> FetchDescriptor<MoneyTransaction> {
        guard let categoryID else {
            return FetchDescriptor(predicate: #Predicate { _ in false })
        }

        let id: UUID? = categoryID
        return FetchDescriptor(
            predicate: #Predicate { $0.categoryID == id },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
    }

    /// How many history rows, transactions and transfers, a query would show.
    /// A failed fetch counts as nothing, the way an empty store would.
    @MainActor
    static func resultCount(
        of query: TransactionQuery,
        in context: ModelContext,
        categoryNames: [UUID: String],
        accountNames: [UUID: String]
    ) -> Int {
        let transactions = (try? context.fetch(Self.transactions(in: query.range))) ?? []
        let transfers = (try? context.fetch(Self.transfers(in: query.range))) ?? []

        return TransactionSearch.results(
            of: query, transactions: transactions,
            categoryNames: categoryNames, accountNames: accountNames
        ).count
            + TransactionSearch.transferResults(
                of: query, transfers: transfers, accountNames: accountNames
            ).count
    }
}
