import Foundation
import SwiftData

/// Folds duplicated rows back into one.
///
/// ## Why the store needs this at all
///
/// Several of this app's identities are unique by a rule the drafts enforce
/// before a write: a category by its kind and name, an instrument by its
/// ticker, the anchor account by its fixed id. None of them is unique by an
/// `@Attribute(.unique)`, because CloudKit forbids those.
///
/// A draft can only check what the device can already see. Two devices that
/// have not met yet both pass their own check, and the duplicate appears at the
/// moment they meet. The clearest case needs no race at all: a second device
/// installs, finds an empty store, seeds nine starter categories and the anchor
/// account, and then synchronisation delivers the nine and the anchor the first
/// device already had.
///
/// So the rule is enforced twice: by the draft before a write, and by this
/// afterwards.
///
/// ## What folding means
///
/// The survivor keeps its identity and everything naming a duplicate is
/// repointed at it before the duplicate is deleted, so no balance, no total and
/// no history moves. The anchor account needs no repointing at all: its
/// duplicates share one fixed id, which is what made them duplicates.
@MainActor
enum StoreReconciler {
    struct Report: Equatable {
        var categories = 0
        var instruments = 0
        var accounts = 0
        var budgetJars = 0
        var transactions = 0
        var transfers = 0

        var isEmpty: Bool {
            categories == 0 && instruments == 0 && accounts == 0 && budgetJars == 0
                && transactions == 0 && transfers == 0
        }
    }

    /// Idempotent: a store with nothing duplicated is left untouched and
    /// reports zero, so this can run on every launch.
    @discardableResult
    static func reconcile(in context: ModelContext) throws -> Report {
        var report = Report()

        report.categories = try foldCategories(in: context)
        report.instruments = try foldInstruments(in: context)
        report.accounts = try foldAnchorAccounts(in: context)
        report.budgetJars = try foldBudgetJars(in: context)
        report.transactions = try foldGeneratedTransactions(in: context)
        report.transactions += try foldImportedTransactions(in: context)
        report.transfers = try foldImportedTransfers(in: context)

        if !report.isEmpty {
            try context.save()
        }

        return report
    }

    /// Matched on kind and name, case-insensitively — the same rule
    /// `CategoryDraft` rejects a duplicate by.
    private static func foldCategories(in context: ModelContext) throws -> Int {
        let categories = try context.fetch(FetchDescriptor<TransactionCategory>())
        let merges = DuplicateReconciler.merges(
            in: categories,
            key: { "\($0.kind.rawValue)|\($0.name.trimmed().lowercased())" },
            createdAt: \.createdAt,
            id: \.id
        )
        guard !merges.isEmpty else {
            return 0
        }

        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let rules = try context.fetch(FetchDescriptor<RecurringRule>())
        var folded = 0

        for merge in merges {
            let doomed = Set(merge.duplicates.map(\.id))
            for transaction in transactions
            where transaction.categoryID.map(doomed.contains) == true {
                transaction.categoryID = merge.survivor.id
            }
            // A rule files what it will record next, so it has to follow the
            // survivor too, or tomorrow's entry lands under a deleted category.
            for rule in rules where rule.categoryID.map(doomed.contains) == true {
                rule.categoryID = merge.survivor.id
            }
            for duplicate in merge.duplicates {
                context.delete(duplicate)
                folded += 1
            }
        }

        return folded
    }

    /// Matched on the uppercased ticker — the same rule
    /// `FundInstrumentDraft` rejects a duplicate by.
    private static func foldInstruments(in context: ModelContext) throws -> Int {
        let instruments = try context.fetch(FetchDescriptor<FundInstrument>())
        let merges = DuplicateReconciler.merges(
            in: instruments,
            key: { $0.symbol.trimmed().uppercased() },
            createdAt: \.createdAt,
            id: \.id
        )
        guard !merges.isEmpty else {
            return 0
        }

        let holdings = try context.fetch(FetchDescriptor<FundHolding>())
        var folded = 0

        for merge in merges {
            let doomed = Set(merge.duplicates.map(\.id))
            for holding in holdings where holding.instrumentID.map(doomed.contains) == true {
                holding.instrumentID = merge.survivor.id
            }
            for duplicate in merge.duplicates {
                context.delete(duplicate)
                folded += 1
            }
        }

        return folded
    }

    /// Matched on the id itself.
    ///
    /// Seeded accounts can duplicate this way because their ids are fixed across
    /// devices. Owner-created accounts use fresh ids and never collide.
    ///
    /// Nothing is repointed because nothing needs to be. The duplicates carry
    /// the same id, so every foreign key naming one already names the survivor.
    private static func foldAnchorAccounts(in context: ModelContext) throws -> Int {
        let accounts = try context.fetch(FetchDescriptor<CashAccount>())
        let merges = DuplicateReconciler.merges(
            in: accounts,
            key: { $0.id.uuidString },
            createdAt: \.createdAt,
            id: \.id
        )

        var folded = 0
        for merge in merges {
            for duplicate in merge.duplicates {
                context.delete(duplicate)
                folded += 1
            }
        }

        return folded
    }

    /// Seeded jars use fixed ids on every device, so CloudKit can materialize
    /// two physical rows that represent the same logical jar.
    private static func foldBudgetJars(in context: ModelContext) throws -> Int {
        let jars = try context.fetch(FetchDescriptor<BudgetJar>())
        let merges = DuplicateReconciler.merges(
            in: jars,
            key: { $0.id.uuidString },
            createdAt: \.createdAt,
            id: \.id
        )

        var folded = 0
        for merge in merges {
            for duplicate in merge.duplicates {
                context.delete(duplicate)
                folded += 1
            }
        }

        return folded
    }

    /// Matched on the rule that wrote the transaction and the day it fell on —
    /// the same pair `RecurringGenerator` refuses to write twice.
    ///
    /// The generator can only check what its own device already holds, so two
    /// devices that had not met yet both generate the month's rent and the
    /// duplicate lands when synchronisation does. A hand-typed transaction has
    /// no rule id and is never folded: two lunches on one day are two lunches.
    ///
    /// Nothing is repointed because a transaction has no children.
    private static func foldGeneratedTransactions(in context: ModelContext) throws -> Int {
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let merges = DuplicateReconciler.merges(
            in: transactions,
            key: { transaction in
                guard let sourceRuleID = transaction.sourceRuleID else {
                    // Dropped by `merges`, which skips an empty key.
                    return ""
                }

                return RecurringGenerator.key(
                    ruleID: sourceRuleID,
                    occurredAt: transaction.occurredAt
                )
            },
            createdAt: \.createdAt,
            id: \.id
        )

        var folded = 0
        for merge in merges {
            for duplicate in merge.duplicates {
                context.delete(duplicate)
                folded += 1
            }
        }

        return folded
    }

    /// A candidate fingerprint is the cross-device identity of an imported
    /// transaction. The immutable financial fields also have to agree: if two
    /// records claim one source but point at different money movements, neither
    /// is safe to discard. Owner-editable note and category do not participate;
    /// oldest-wins settles those just like every other CloudKit fold.
    private static func foldImportedTransactions(in context: ModelContext) throws -> Int {
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        let merges = DuplicateReconciler.merges(
            in: transactions,
            key: { transaction in
                guard transaction.sourceRuleID == nil,
                    let sourceID = transaction.sourceImportID.flatMap({
                        ImportSourceID(rawValue: $0)
                    })
                else {
                    return ""
                }

                return [
                    sourceID.rawValue,
                    transaction.kind.rawValue,
                    decimalKey(transaction.amount),
                    dateKey(transaction.occurredAt),
                    transaction.accountID.uuidString,
                    transaction.currencyCode,
                ].joined(separator: "|")
            },
            createdAt: \.createdAt,
            id: \.id
        )

        var folded = 0
        for merge in merges {
            for duplicate in merge.duplicates {
                context.delete(duplicate)
                folded += 1
            }
        }

        return folded
    }

    private enum TransferImportSide {
        case source
        case destination

        func fingerprint(of transfer: AccountTransfer) -> String? {
            switch self {
            case .source:
                transfer.sourceAccountImportID
            case .destination:
                transfer.destinationAccountImportID
            }
        }

        func oppositeFingerprint(of transfer: AccountTransfer) -> String? {
            switch self {
            case .source:
                transfer.destinationAccountImportID
            case .destination:
                transfer.sourceAccountImportID
            }
        }

        func setOppositeFingerprint(_ fingerprint: String, on transfer: AccountTransfer) {
            switch self {
            case .source:
                transfer.destinationAccountImportID = fingerprint
            case .destination:
                transfer.sourceAccountImportID = fingerprint
            }
        }
    }

    /// Source and destination provenance are distinct identities. Folding one
    /// side may discover the other side's fingerprint on a duplicate, so that
    /// value is copied to the survivor before deletion. Different non-nil
    /// opposite fingerprints are a conflict and leave the whole group alone.
    private static func foldImportedTransfers(in context: ModelContext) throws -> Int {
        try foldImportedTransfers(on: .source, in: context)
            + foldImportedTransfers(on: .destination, in: context)
    }

    private static func foldImportedTransfers(
        on side: TransferImportSide,
        in context: ModelContext
    ) throws -> Int {
        let transfers = try context.fetch(FetchDescriptor<AccountTransfer>())
        let merges = DuplicateReconciler.merges(
            in: transfers,
            key: { transfer in
                guard let rawSourceID = side.fingerprint(of: transfer),
                    let sourceID = ImportSourceID(rawValue: rawSourceID)
                else {
                    return ""
                }

                return [
                    sourceID.rawValue,
                    decimalKey(transfer.amount),
                    dateKey(transfer.occurredAt),
                    transfer.sourceAccountID.uuidString,
                    transfer.destinationAccountID.uuidString,
                    transfer.currencyCode,
                ].joined(separator: "|")
            },
            createdAt: \.createdAt,
            id: \.id
        )

        var folded = 0
        for merge in merges {
            let members = [merge.survivor] + merge.duplicates
            let rawOppositeIDs = members.compactMap(side.oppositeFingerprint(of:))
            let oppositeIDs = rawOppositeIDs.compactMap { ImportSourceID(rawValue: $0) }
            guard oppositeIDs.count == rawOppositeIDs.count,
                Set(oppositeIDs).count <= 1
            else {
                continue
            }

            if side.oppositeFingerprint(of: merge.survivor) == nil,
                let oppositeID = oppositeIDs.first
            {
                side.setOppositeFingerprint(oppositeID.rawValue, on: merge.survivor)
            }
            for duplicate in merge.duplicates {
                context.delete(duplicate)
                folded += 1
            }
        }

        return folded
    }

    private static func decimalKey(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func dateKey(_ value: Date) -> String {
        String(value.timeIntervalSinceReferenceDate.bitPattern, radix: 16)
    }
}

extension String {
    fileprivate func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
