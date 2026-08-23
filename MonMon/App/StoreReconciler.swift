import Foundation
import SwiftData

/// Folds duplicated rows back into one.
///
/// ## Why the store needs this at all
///
/// Three of this app's identities are unique by a rule the drafts enforce
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

        var isEmpty: Bool {
            categories == 0 && instruments == 0 && accounts == 0
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
        var folded = 0

        for merge in merges {
            let doomed = Set(merge.duplicates.map(\.id))
            for transaction in transactions
            where transaction.categoryID.map(doomed.contains) == true {
                transaction.categoryID = merge.survivor.id
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
    /// Only the anchor can duplicate this way — every other account is created
    /// with a fresh id, so two of them never collide — but keying on the id
    /// rather than on "is this the anchor" costs nothing and states the actual
    /// invariant: one row per id.
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
}

extension String {
    fileprivate func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
