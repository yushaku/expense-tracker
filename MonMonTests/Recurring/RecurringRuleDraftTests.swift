import Foundation
import Testing

@testable import MonMon

@Suite("Recurring rule draft validation")
struct RecurringRuleDraftTests {
    private let accountID = UUID()
    private let categoryID = UUID()

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) throws -> Date {
        try #require(
            RecurrenceSchedule.calendar.date(
                from: DateComponents(year: year, month: month, day: dayOfMonth)
            )
        )
    }

    private func makeDraft(
        kind: TransactionKind = .expense,
        amountText: String = "8.000.000",
        note: String = "Rent",
        accountID: UUID? = nil,
        categoryID: UUID? = nil,
        frequency: RecurrenceFrequency = .monthly,
        intervalText: String = "1",
        anchorDate: Date,
        hasEndDate: Bool = false,
        endDate: Date? = nil,
        isPaused: Bool = false
    ) -> RecurringRuleDraft {
        RecurringRuleDraft(
            kind: kind,
            amountText: amountText,
            note: note,
            accountID: accountID ?? self.accountID,
            categoryID: categoryID ?? self.categoryID,
            frequency: frequency,
            intervalText: intervalText,
            anchorDate: anchorDate,
            hasEndDate: hasEndDate,
            endDate: endDate,
            isPaused: isPaused
        )
    }

    @Test("A complete draft validates into the values a rule is written from")
    func completeDraftValidates() throws {
        let anchor = try day(2026, 8, 5)
        let draft = makeDraft(note: "  Rent  ", anchorDate: anchor)

        let values = try draft.validate(asOf: try day(2026, 8, 24))

        #expect(values.kind == .expense)
        #expect(values.amount == 8_000_000)
        #expect(values.note == "Rent")
        #expect(values.accountID == accountID)
        #expect(values.categoryID == categoryID)
        #expect(values.frequency == .monthly)
        #expect(values.interval == 1)
        #expect(values.anchorDate == anchor)
        #expect(values.endDate == nil)
        #expect(values.isPaused == false)
    }

    @Test("An unparseable amount is rejected")
    func unparseableAmountIsRejected() throws {
        let draft = makeDraft(amountText: "abc", anchorDate: try day(2026, 8, 5))

        #expect(throws: RecurringFormError.invalidAmount) {
            try draft.validate(asOf: try day(2026, 8, 24))
        }
    }

    @Test("A zero amount is rejected")
    func zeroAmountIsRejected() throws {
        let draft = makeDraft(amountText: "0", anchorDate: try day(2026, 8, 5))

        #expect(throws: RecurringFormError.nonPositiveAmount) {
            try draft.validate(asOf: try day(2026, 8, 24))
        }
    }

    @Test("A missing account is rejected")
    func missingAccountIsRejected() throws {
        var draft = makeDraft(anchorDate: try day(2026, 8, 5))
        draft.accountID = nil

        #expect(throws: RecurringFormError.missingAccount) {
            try draft.validate(asOf: try day(2026, 8, 24))
        }
    }

    @Test("A missing category is rejected")
    func missingCategoryIsRejected() throws {
        var draft = makeDraft(anchorDate: try day(2026, 8, 5))
        draft.categoryID = nil

        #expect(throws: RecurringFormError.missingCategory) {
            try draft.validate(asOf: try day(2026, 8, 24))
        }
    }

    @Test("An interval that is not a whole number above zero is rejected")
    func invalidIntervalIsRejected() throws {
        let anchor = try day(2026, 8, 5)
        let asOf = try day(2026, 8, 24)

        for text in ["0", "-1", "", "two", "1,5"] {
            let draft = makeDraft(intervalText: text, anchorDate: anchor)

            #expect(throws: RecurringFormError.invalidInterval) {
                try draft.validate(asOf: asOf)
            }
        }
    }

    @Test("Surrounding spaces do not spoil an interval")
    func intervalToleratesSpaces() throws {
        let draft = makeDraft(intervalText: " 2 ", anchorDate: try day(2026, 8, 5))

        let values = try draft.validate(asOf: try day(2026, 8, 24))

        #expect(values.interval == 2)
    }

    @Test("An end date before the anchor is rejected")
    func endDateBeforeAnchorIsRejected() throws {
        let draft = makeDraft(
            anchorDate: try day(2026, 8, 5),
            hasEndDate: true,
            endDate: try day(2026, 7, 5)
        )

        #expect(throws: RecurringFormError.endDateBeforeAnchor) {
            try draft.validate(asOf: try day(2026, 8, 24))
        }
    }

    @Test("An end date on the anchor itself is allowed")
    func endDateOnTheAnchorIsAllowed() throws {
        let anchor = try day(2026, 8, 5)
        let draft = makeDraft(anchorDate: anchor, hasEndDate: true, endDate: anchor)

        let values = try draft.validate(asOf: try day(2026, 8, 24))

        #expect(values.endDate == anchor)
    }

    @Test("A backfill beyond the ceiling is rejected and names the count")
    func oversizedBackfillIsRejected() throws {
        let draft = makeDraft(
            frequency: .daily,
            anchorDate: try day(2020, 1, 1)
        )

        #expect(throws: RecurringFormError.tooManyOccurrences(401)) {
            try draft.validate(asOf: try day(2026, 8, 24))
        }
    }

    @Test("A backfill sitting exactly on the ceiling is allowed")
    func backfillOnTheCeilingIsAllowed() throws {
        let anchor = try day(2026, 8, 24)
        let end = try #require(
            RecurrenceSchedule.calendar.date(
                byAdding: .day,
                value: RecurringRuleDraft.maxBackfill - 1,
                to: anchor
            )
        )
        let draft = makeDraft(frequency: .daily, anchorDate: anchor)

        let values = try draft.validate(asOf: end)

        #expect(values.interval == 1)
    }

    /// Editing a rule that has been running for years measures what saving it
    /// would add, not the whole history it already wrote.
    @Test("Already generated occurrences do not count towards the ceiling")
    func generatedOccurrencesDoNotCountTowardsTheCeiling() throws {
        let draft = makeDraft(frequency: .daily, anchorDate: try day(2020, 1, 1))

        let values = try draft.validate(
            asOf: try day(2026, 8, 24),
            generatedThrough: try day(2026, 8, 20)
        )

        #expect(values.frequency == .daily)
    }

    @Test("A rule round trips into a draft and back")
    func ruleRoundTripsThroughADraft() throws {
        let anchor = try day(2026, 8, 5)
        let end = try day(2027, 8, 5)
        let rule = try makeDraft(
            kind: .income,
            amountText: "25.000.000",
            note: "Salary",
            frequency: .weekly,
            intervalText: "2",
            anchorDate: anchor,
            hasEndDate: true,
            endDate: end
        )
        .makeRule(id: UUID(), createdAt: anchor, asOf: try day(2026, 8, 24))

        let draft = RecurringRuleDraft(rule: rule)

        #expect(draft.kind == .income)
        #expect(draft.amountText == VNDCurrency.formatPlain(25_000_000))
        #expect(draft.note == "Salary")
        #expect(draft.frequency == .weekly)
        #expect(draft.intervalText == "2")
        #expect(draft.anchorDate == anchor)
        #expect(draft.hasEndDate)
        #expect(draft.endDate == end)
        #expect(rule.lastGeneratedAt == nil)
    }

    @Test("Editing rewrites every field and leaves generation where it was")
    func editingRewritesEveryField() throws {
        let anchor = try day(2026, 8, 5)
        let asOf = try day(2026, 8, 24)
        let generatedThrough = try day(2026, 8, 5)
        let rule = try makeDraft(anchorDate: anchor)
            .makeRule(id: UUID(), createdAt: anchor, asOf: asOf)
        rule.lastGeneratedAt = generatedThrough

        var draft = RecurringRuleDraft(rule: rule)
        draft.amountText = "9.000.000"
        draft.intervalText = "3"
        try draft.apply(to: rule, asOf: asOf)

        #expect(rule.amount == 9_000_000)
        #expect(rule.interval == 3)
        #expect(rule.lastGeneratedAt == generatedThrough)
    }

    @Test("A failed edit leaves the rule untouched")
    func failedEditLeavesTheRuleAlone() throws {
        let anchor = try day(2026, 8, 5)
        let asOf = try day(2026, 8, 24)
        let rule = try makeDraft(anchorDate: anchor)
            .makeRule(id: UUID(), createdAt: anchor, asOf: asOf)

        var draft = RecurringRuleDraft(rule: rule)
        draft.amountText = "-5"

        #expect(throws: RecurringFormError.self) {
            try draft.apply(to: rule, asOf: asOf)
        }
        #expect(rule.amount == 8_000_000)
    }

    /// Pausing is how the owner says those occurrences did not happen, so
    /// resuming must not hand them back.
    @Test("Resuming a paused rule does not backfill the paused stretch")
    func resumingDoesNotBackfillThePausedStretch() throws {
        let anchor = try day(2026, 1, 5)
        let asOf = try day(2026, 8, 24)
        let rule = try makeDraft(anchorDate: anchor, isPaused: true)
            .makeRule(id: UUID(), createdAt: anchor, asOf: asOf)
        rule.lastGeneratedAt = try day(2026, 3, 5)

        var draft = RecurringRuleDraft(rule: rule)
        draft.isPaused = false
        try draft.apply(to: rule, asOf: asOf)

        #expect(rule.isPaused == false)
        #expect(rule.lastGeneratedAt == asOf)
        #expect(rule.pendingOccurrences(asOf: asOf, limit: 400).isEmpty)
    }

    @Test("Pausing an active rule leaves generation where it was")
    func pausingKeepsGenerationWhereItWas() throws {
        let anchor = try day(2026, 1, 5)
        let asOf = try day(2026, 8, 24)
        let generatedThrough = try day(2026, 3, 5)
        let rule = try makeDraft(anchorDate: anchor)
            .makeRule(id: UUID(), createdAt: anchor, asOf: asOf)
        rule.lastGeneratedAt = generatedThrough

        var draft = RecurringRuleDraft(rule: rule)
        draft.isPaused = true
        try draft.apply(to: rule, asOf: asOf)

        #expect(rule.isPaused)
        #expect(rule.lastGeneratedAt == generatedThrough)
    }
}
