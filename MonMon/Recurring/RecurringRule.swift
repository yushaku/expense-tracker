import Foundation
import SwiftData

/// One instruction to record the same transaction again and again: rent on the
/// 5th, salary on the 25th, a streaming subscription every month.
///
/// A rule is not money. It holds no balance and reaches no total; it only
/// stamps out `MoneyTransaction` rows, and those rows are what every balance and
/// every total is derived from, exactly as a hand-typed one would be. Deleting
/// a rule therefore needs no compensating write: what it already recorded really
/// happened.
///
/// The payload fields mirror `MoneyTransaction` field for field, so what the
/// generator writes is decided here rather than assembled at the call site.
@Model
final class RecurringRule {
    var id: UUID = UUID()
    var kind: TransactionKind = TransactionKind.expense
    /// Always positive. `kind` carries the direction, the same way
    /// `MoneyTransaction.amount` does.
    var amount: Decimal = Decimal.zero
    /// Doubles as the rule's name on screen, because "Rent" is both.
    var note: String = ""
    /// Identifier of the cash account the money moves through. Required, for the
    /// reason `MoneyTransaction.accountID` is: a transaction with no account
    /// cannot move a balance.
    var accountID: UUID = AccountSeed.unassignedID
    /// Optional so a half-finished category deletion cannot destroy a rule,
    /// matching `MoneyTransaction.categoryID`.
    var categoryID: UUID?
    var currencyCode: String = VNDCurrency.code
    var frequency: RecurrenceFrequency = RecurrenceFrequency.monthly
    /// How many units of `frequency` separate two occurrences. Always at least
    /// one; "every 2 weeks" is `weekly` with an interval of two.
    var interval: Int = 1
    /// The first occurrence. It may sit in the past, which is what lets a rule
    /// added today record the months it already covered.
    var anchorDate: Date = Date(timeIntervalSince1970: 0)
    /// The last day an occurrence may fall on, inclusive. `nil` is open-ended,
    /// which most household bills are.
    var endDate: Date?
    /// Stops generation without losing the rule or anything it already wrote.
    var isPaused: Bool = false
    /// Start of the newest day this rule has already been generated through.
    /// `nil` means nothing has been written yet, so generation starts at the
    /// anchor. It is the only piece of state the generator advances.
    var lastGeneratedAt: Date?
    var createdAt: Date = Date(timeIntervalSince1970: 0)

    init(
        id: UUID,
        kind: TransactionKind,
        amount: Decimal,
        note: String,
        accountID: UUID,
        categoryID: UUID?,
        currencyCode: String,
        frequency: RecurrenceFrequency,
        interval: Int,
        anchorDate: Date,
        endDate: Date?,
        isPaused: Bool,
        lastGeneratedAt: Date?,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.note = note
        self.accountID = accountID
        self.categoryID = categoryID
        self.currencyCode = currencyCode
        self.frequency = frequency
        self.interval = interval
        self.anchorDate = anchorDate
        self.endDate = endDate
        self.isPaused = isPaused
        self.lastGeneratedAt = lastGeneratedAt
        self.createdAt = createdAt
    }
}

extension RecurringRule {
    /// How the schedule reads on screen: "Every 2 weeks".
    func schedulePhrase(in locale: Locale) -> String {
        frequency.phrase(interval: interval, in: locale)
    }

    /// The dates this rule still owes, oldest first, up to and including
    /// `asOf`. A paused rule owes nothing, and nothing is ever owed past
    /// `endDate`.
    ///
    /// `asOf` is passed in rather than read from the clock, so the answer is
    /// reproducible — the rule every `asOf:` parameter in this app follows.
    func pendingOccurrences(asOf: Date, limit: Int) -> [Date] {
        guard !isPaused else {
            return []
        }

        let bound = endDate.map { min($0, asOf) } ?? asOf

        return RecurrenceSchedule.occurrences(
            frequency: frequency,
            interval: interval,
            anchor: anchorDate,
            after: lastGeneratedAt,
            through: bound,
            limit: limit
        )
    }

    /// The next date this rule falls due after `asOf`, or `nil` when it is
    /// paused or has run past its end date.
    func nextOccurrence(after asOf: Date) -> Date? {
        guard !isPaused else {
            return nil
        }

        guard
            let next = RecurrenceSchedule.nextOccurrence(
                frequency: frequency,
                interval: interval,
                anchor: anchorDate,
                after: asOf
            )
        else {
            return nil
        }

        if let endDate, next > RecurrenceSchedule.calendar.startOfDay(for: endDate) {
            return nil
        }

        return next
    }
}
