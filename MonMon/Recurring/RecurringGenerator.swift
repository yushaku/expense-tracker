import Foundation
import SwiftData

/// Turns a rule that has fallen due into the transactions it promised.
///
/// ## Why this runs on launch rather than on a timer
///
/// Nothing in this app runs in the background: prices refresh only when the
/// owner asks, and synchronisation is the system's to schedule. A recurring rule
/// keeps that grain by catching up instead of waking up. Opening the app is what
/// asks, and because every occurrence is derived from the rule's anchor rather
/// than from when the app happened to be running, a month spent away is a month
/// recorded in full the moment the owner comes back.
///
/// ## Why a generated transaction is an ordinary transaction
///
/// It is written as a plain `MoneyTransaction`, carrying nothing but the id of
/// the rule that produced it. Every balance and every total is already derived
/// from those rows, so a generated one moves the account, the Spending totals,
/// the category breakdown, and net worth with no further work — and the owner can
/// edit or delete it like any other, because it records money that really moved.
@MainActor
enum RecurringGenerator {
    /// The most occurrences one rule may write in a single pass.
    /// `RecurringRuleDraft` refuses to save a rule that would exceed this, so
    /// reaching it here means a store that arrived from somewhere else. The
    /// remainder is written on the next pass rather than lost.
    static let maxOccurrencesPerRule = RecurringRuleDraft.maxBackfill

    struct Report: Equatable {
        var rules = 0
        var transactions = 0

        var isEmpty: Bool {
            transactions == 0
        }
    }

    /// Idempotent: a store whose rules are all caught up is left untouched and
    /// reports zero, so this can run on every launch and every return to the
    /// foreground.
    ///
    /// `asOf` is a parameter rather than a call to the clock so the behaviour is
    /// reproducible, matching every other `asOf:` in the app.
    @discardableResult
    static func generate(in context: ModelContext, asOf: Date = .now) throws -> Report {
        let rules = try context.fetch(FetchDescriptor<RecurringRule>())
        guard !rules.isEmpty else {
            return Report()
        }

        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let jars = try context.fetch(FetchDescriptor<BudgetJar>())
        var written = existingKeys(in: transactions)
        var report = Report()

        for rule in rules {
            let occurrences = rule.pendingOccurrences(
                asOf: asOf,
                limit: maxOccurrencesPerRule
            )
            guard !occurrences.isEmpty else {
                continue
            }

            var inserted = 0

            for occurredAt in occurrences {
                // A rule may only ever produce one transaction per day. The
                // check sees only this device's rows, so a peer that generated
                // the same day before the two met can still produce a duplicate;
                // `StoreReconciler` folds that one afterwards.
                let key = key(ruleID: rule.id, occurredAt: occurredAt)
                guard !written.contains(key) else {
                    continue
                }
                written.insert(key)

                let transaction = MoneyTransaction(
                    id: UUID(),
                    kind: rule.kind,
                    amount: rule.amount,
                    occurredAt: occurredAt,
                    note: rule.note,
                    accountID: rule.accountID,
                    categoryID: rule.categoryID,
                    sourceRuleID: rule.id,
                    currencyCode: rule.currencyCode,
                    createdAt: asOf
                )
                try IncomeAllocationLifecycle.captureNew(
                    on: transaction,
                    jars: jars,
                    capturedAt: asOf
                )
                context.insert(transaction)
                inserted += 1
            }

            // Advanced to the last date considered, not to the last date
            // written: an occurrence skipped because it already existed is an
            // occurrence this rule is caught up on.
            if let newest = occurrences.last {
                rule.lastGeneratedAt = newest
            }

            if inserted > 0 {
                report.rules += 1
                report.transactions += inserted
            }
        }

        // Asked of the context rather than of the report, because a rule whose
        // dates were all already present wrote no transaction and still moved
        // its `lastGeneratedAt`.
        if context.hasChanges {
            try context.save()
        }

        return report
    }

    /// One rule, one day. The pair `StoreReconciler` folds duplicates on.
    static func key(ruleID: UUID, occurredAt: Date) -> String {
        let day = RecurrenceSchedule.calendar.startOfDay(for: occurredAt)
        return "\(ruleID.uuidString)|\(day.timeIntervalSince1970)"
    }

    private static func existingKeys(in transactions: [MoneyTransaction]) -> Set<String> {
        var keys: Set<String> = []

        for transaction in transactions {
            guard let sourceRuleID = transaction.sourceRuleID else {
                continue
            }
            keys.insert(key(ruleID: sourceRuleID, occurredAt: transaction.occurredAt))
        }

        return keys
    }
}
