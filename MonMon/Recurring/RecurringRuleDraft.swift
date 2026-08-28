import Foundation

enum RecurringFormError: Error, Equatable {
    case invalidAmount
    case nonPositiveAmount
    case missingAccount
    case missingCategory
    case invalidInterval
    case endDateBeforeAnchor
    /// The rule would write more than `RecurringRuleDraft.maxBackfill` rows the
    /// moment it was saved. Carries the count so the message can name it.
    case tooManyOccurrences(Int)
}

/// Validates what the owner typed before any `RecurringRule` is written, the
/// same boundary `TransactionDraft` draws for a single transaction.
struct RecurringRuleDraft: Equatable {
    /// The most occurrences one save may backfill. A daily rule anchored five
    /// years back would otherwise insert about eighteen hundred transactions the
    /// instant it was saved, which is not an entry the owner can undo by hand.
    /// `RecurringGenerator` enforces the same ceiling per pass.
    static let maxBackfill = 400

    var kind: TransactionKind
    @VNDInput var amountText: String
    var note: String
    var accountID: UUID?
    var categoryID: UUID?
    var frequency: RecurrenceFrequency
    var intervalText: String
    var anchorDate: Date
    /// Held apart from `endDate` because `DateField` binds a non-optional
    /// `Date`, so the toggle owns whether the date is used at all — the pairing
    /// `DebtDraft` established for its due date.
    var hasEndDate: Bool
    var endDate: Date
    var isPaused: Bool

    init(
        kind: TransactionKind = .expense,
        amountText: String = "",
        note: String = "",
        accountID: UUID? = nil,
        categoryID: UUID? = nil,
        frequency: RecurrenceFrequency = .monthly,
        intervalText: String = "1",
        anchorDate: Date,
        hasEndDate: Bool = false,
        endDate: Date? = nil,
        isPaused: Bool = false
    ) {
        self.kind = kind
        self.amountText = amountText
        self.note = note
        self.accountID = accountID
        self.categoryID = categoryID
        self.frequency = frequency
        self.intervalText = intervalText
        self.anchorDate = anchorDate
        self.hasEndDate = hasEndDate
        self.endDate = endDate ?? anchorDate
        self.isPaused = isPaused
    }

    init(rule: RecurringRule) {
        self.init(
            kind: rule.kind,
            amountText: VNDCurrency.formatPlain(rule.amount),
            note: rule.note,
            accountID: rule.accountID,
            categoryID: rule.categoryID,
            frequency: rule.frequency,
            intervalText: String(rule.interval),
            anchorDate: rule.anchorDate,
            hasEndDate: rule.endDate != nil,
            endDate: rule.endDate,
            isPaused: rule.isPaused
        )
    }

    /// Validated values ready to write to a model.
    struct ValidatedValues: Equatable {
        var kind: TransactionKind
        var amount: Decimal
        var note: String
        var accountID: UUID
        var categoryID: UUID
        var frequency: RecurrenceFrequency
        var interval: Int
        var anchorDate: Date
        var endDate: Date?
        var isPaused: Bool
    }

    /// - Parameters:
    ///   - asOf: the day the backfill would be measured up to. Passed in rather
    ///     than read from the clock, so the check is reproducible.
    ///   - generatedThrough: what the rule has already written, so editing a
    ///     long-running rule is measured by what saving it would add rather than
    ///     by its whole history. `nil` for a rule being added.
    func validate(asOf: Date, generatedThrough: Date? = nil) throws -> ValidatedValues {
        guard let amount = VNDCurrency.parse(amountText) else {
            throw RecurringFormError.invalidAmount
        }

        guard amount > 0 else {
            throw RecurringFormError.nonPositiveAmount
        }

        guard let accountID else {
            throw RecurringFormError.missingAccount
        }

        guard let categoryID else {
            throw RecurringFormError.missingCategory
        }

        guard
            let interval = Int(intervalText.trimmingCharacters(in: .whitespaces)),
            interval >= 1
        else {
            throw RecurringFormError.invalidInterval
        }

        let calendar = RecurrenceSchedule.calendar
        let anchor = calendar.startOfDay(for: anchorDate)
        let end = hasEndDate ? calendar.startOfDay(for: endDate) : nil

        if let end, end < anchor {
            throw RecurringFormError.endDateBeforeAnchor
        }

        // Asks for one more than the ceiling, so exceeding it is distinguishable
        // from sitting exactly on it.
        let backfill = RecurrenceSchedule.occurrences(
            frequency: frequency,
            interval: interval,
            anchor: anchor,
            after: generatedThrough,
            through: end.map { min($0, asOf) } ?? asOf,
            limit: Self.maxBackfill + 1
        )

        if backfill.count > Self.maxBackfill {
            throw RecurringFormError.tooManyOccurrences(backfill.count)
        }

        return ValidatedValues(
            kind: kind,
            amount: amount,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            accountID: accountID,
            categoryID: categoryID,
            frequency: frequency,
            interval: interval,
            anchorDate: anchor,
            endDate: end,
            isPaused: isPaused
        )
    }

    func makeRule(id: UUID, createdAt: Date, asOf: Date) throws -> RecurringRule {
        let values = try validate(asOf: asOf)

        return RecurringRule(
            id: id,
            kind: values.kind,
            amount: values.amount,
            note: values.note,
            accountID: values.accountID,
            categoryID: values.categoryID,
            currencyCode: VNDCurrency.code,
            frequency: values.frequency,
            interval: values.interval,
            anchorDate: values.anchorDate,
            endDate: values.endDate,
            isPaused: values.isPaused,
            lastGeneratedAt: nil,
            createdAt: createdAt
        )
    }

    /// Editing a rule changes what it will write next. What it already wrote is
    /// money that already moved, so no existing transaction is touched here.
    func apply(to rule: RecurringRule, asOf: Date) throws {
        let values = try validate(asOf: asOf, generatedThrough: rule.lastGeneratedAt)

        // Resuming does not backfill the stretch the rule spent paused: pausing
        // is how the owner says those occurrences did not happen. Generation
        // picks up from today instead.
        if rule.isPaused, !values.isPaused {
            rule.lastGeneratedAt = RecurrenceSchedule.calendar.startOfDay(for: asOf)
        }

        rule.kind = values.kind
        rule.amount = values.amount
        rule.note = values.note
        rule.accountID = values.accountID
        rule.categoryID = values.categoryID
        rule.frequency = values.frequency
        rule.interval = values.interval
        rule.anchorDate = values.anchorDate
        rule.endDate = values.endDate
        rule.isPaused = values.isPaused
    }
}
