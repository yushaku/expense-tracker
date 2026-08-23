import Foundation
import SwiftData

/// The account that always exists, so a foreign key naming an account always
/// resolves to one.
///
/// ## Why this exists
///
/// CloudKit will not accept an attribute that is neither optional nor
/// defaulted, and the accounts a record points at — the account a transaction
/// was recorded against, the two ends of a transfer, the account a debt payment
/// moved through — have no natural default. `UUID()` would be worse than none:
/// an identifier pointing at nothing, wearing the shape of a valid one.
///
/// So the app guarantees one account instead of inventing one per record. Every
/// account-shaped foreign key defaults to `unassignedID`, and this row is
/// written on every launch, so the default always names something real.
///
/// The consequence is worth stating plainly. A record that arrives from a peer
/// with no account of its own lands **here** rather than nowhere, which means it
/// is counted in the spending totals *and* in an account balance, instead of
/// counted in one and not the other. Money that cannot be attributed is money
/// the owner can see and move, not money that quietly stops adding up.
///
/// ## What it does not solve
///
/// A default applies when a field is absent, never when a field holds a value
/// that has stopped resolving. An account deleted on one device while another
/// device was still recording against it leaves records naming the **dead
/// account's** id, not this one. That case needs reporting, not a default.
enum AccountSeed {
    /// Fixed rather than generated, because every device has to seed the same
    /// row: a foreign key that defaults to this id must resolve on all of them,
    /// and a per-device id would resolve on exactly one.
    /// Built from its bytes rather than parsed from a string. A `@Model`
    /// default has to be a plain expression the macro can evaluate while the
    /// schema is being built; a `static let` initialised by a closure is
    /// evaluated lazily instead, and every container in the app then fails to
    /// open. The bytes spell `00000000-0000-0000-0000-000000000001`.
    static let unassignedID = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
    )

    static let unassignedName = "Unassigned"

    /// Written on every launch rather than only into an empty store, because
    /// this row is a referential anchor and not a convenience. `CategorySeed`
    /// seeds only an empty store on purpose — deleting a starter category should
    /// not bring it back — but deleting the anchor would leave every default
    /// foreign key naming nothing, so this one is restored instead.
    ///
    /// Idempotent, and matched on `unassignedID` rather than on the name, so
    /// renaming it in the UI never produces a second one.
    @MainActor
    @discardableResult
    static func ensureUnassignedExists(
        in context: ModelContext,
        createdAt: Date = .now
    ) -> CashAccount {
        // Filtered in Swift rather than through a `#Predicate`. A predicate
        // capturing a `UUID` and comparing it to a non-optional `UUID` property
        // traps at runtime, which takes the whole process with it — the app on
        // launch, and every test that had not finished yet. The account list is
        // a handful of rows, so there is nothing to gain by pushing it down.
        let existing = (try? context.fetch(FetchDescriptor<CashAccount>())) ?? []

        if let found = existing.first(where: { $0.id == unassignedID }) {
            return found
        }

        let account = CashAccount(
            id: unassignedID,
            name: unassignedName,
            kind: .cash,
            openingBalance: .zero,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )
        context.insert(account)
        try? context.save()
        return account
    }

    /// True for the one account the app will not let go of. Deleting it would
    /// leave every default foreign key naming nothing, which is the single state
    /// this whole file exists to prevent.
    static func isUnassigned(_ account: CashAccount) -> Bool {
        account.id == unassignedID
    }
}
