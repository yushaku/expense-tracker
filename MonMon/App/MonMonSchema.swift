import Foundation
import SwiftData

enum MonMonSchema {
    /// Registered in the container and in every in-memory test container, so the
    /// two can never drift apart.
    static var models: [any PersistentModel.Type] {
        [
            CashAccount.self, SavingsDeposit.self,
            FundInstrument.self, FundHolding.self,
            TransactionCategory.self, MoneyTransaction.self, AccountTransfer.self,
            Debt.self, DebtPayment.self,
        ]
    }
}

/// Builds the fund catalogue out of the holdings that already exist.
///
/// ## Why this is a backfill and not a staged migration
///
/// The split wants six properties gone from `FundHolding` and one required
/// property added, which SwiftData cannot infer. The obvious answer is a
/// `VersionedSchema` pair with a custom `MigrationStage`, and that was tried
/// first. It fails at store-open time on a store this app has already written:
///
///     Cannot use staged migration with an unknown model version.
///
/// Staged migration has to recognise the store as the "from" version, and a
/// store created by an unversioned `ModelContainer(for:)` — every build of this
/// app so far — is not recognised. A container that cannot open is an app that
/// cannot launch, on the owner's real records.
///
/// So the schema change is kept **purely additive** instead: `FundInstrument`
/// is a new entity, `instrumentID` is a new optional, and the six pre-split
/// fields stay declared with defaults. SwiftData opens that with no migration
/// at all, and this runs once afterwards to link the two up. Nothing can fail
/// before the app has a UI to report it with.
///
/// The cost is six dead columns on `FundHolding` until a later module drops
/// them, once every store has been through this.
enum FundInstrumentBackfill {
    /// Idempotent: a holding that already points at an instrument is left alone,
    /// so this can run on every launch and does nothing on all but the first.
    ///
    /// Nothing is deleted and no unit count, average cost, or funding link is
    /// touched, so cost basis, funded amount, and every cash balance come out of
    /// it identical. Only a duplicated ticker's price can change, and only
    /// towards the more recent of the two figures it already carried.
    @discardableResult
    static func runIfNeeded(in context: ModelContext) throws -> Int {
        let unlinked = try context.fetch(
            FetchDescriptor<FundHolding>(predicate: #Predicate { $0.instrumentID == nil })
        )
        guard !unlinked.isEmpty else {
            return 0
        }

        var catalogue = try context.fetch(FetchDescriptor<FundInstrument>())
        var linked = 0

        for group in FundInstrumentSeed.group(unlinked.map(FundHoldingSnapshot.init)) {
            let instrument: FundInstrument
            if let existing = catalogue.matching(symbol: group.symbol) {
                instrument = existing
            } else {
                instrument = FundInstrument(
                    id: UUID(),
                    symbol: group.symbol,
                    name: group.name,
                    kind: group.kind,
                    currentPricePerUnit: group.pricePerUnit,
                    priceAsOf: group.priceAsOf,
                    priceSource: FundQuoteSource.manual.rawValue,
                    priceFetchedAt: nil,
                    autoQuoteEnabled: true,
                    currencyCode: group.currencyCode.isEmpty
                        ? VNDCurrency.code : group.currencyCode,
                    createdAt: group.createdAt
                )
                context.insert(instrument)
                catalogue.append(instrument)
            }

            for holding in unlinked where group.holdingIDs.contains(holding.id) {
                holding.instrumentID = instrument.id
                linked += 1
            }
        }

        try context.save()
        return linked
    }
}

/// What the backfill needs to read from a pre-split holding, as plain values so
/// the grouping rule can be tested without a store.
struct FundHoldingSnapshot: Equatable, Sendable {
    var holdingID: UUID
    var name: String
    var symbol: String
    var kind: FundHoldingKind
    var currentNAVPerUnit: Decimal
    var navAsOf: Date
    var currencyCode: String
    var createdAt: Date

    init(
        holdingID: UUID,
        name: String,
        symbol: String,
        kind: FundHoldingKind,
        currentNAVPerUnit: Decimal,
        navAsOf: Date,
        currencyCode: String,
        createdAt: Date
    ) {
        self.holdingID = holdingID
        self.name = name
        self.symbol = symbol
        self.kind = kind
        self.currentNAVPerUnit = currentNAVPerUnit
        self.navAsOf = navAsOf
        self.currencyCode = currencyCode
        self.createdAt = createdAt
    }

    init(_ holding: FundHolding) {
        self.init(
            holdingID: holding.id,
            name: holding.name,
            symbol: holding.symbol,
            kind: holding.kind,
            currentNAVPerUnit: holding.currentNAVPerUnit,
            navAsOf: holding.navAsOf,
            currencyCode: holding.currencyCode,
            createdAt: holding.createdAt
        )
    }
}

/// The grouping rule, kept out of the backfill so it can be tested on values.
enum FundInstrumentSeed {
    struct Group: Equatable {
        var symbol: String
        var name: String
        var kind: FundHoldingKind
        var pricePerUnit: Decimal
        var priceAsOf: Date
        var currencyCode: String
        var createdAt: Date
        var holdingIDs: [UUID]
    }

    /// One group per ticker, compared case-insensitively.
    ///
    /// Identity comes from the group's **oldest** holding, so the first thing the
    /// owner entered wins over a later typo. The price comes from the group's
    /// **newest** `navAsOf`, because when two rows disagreed the more recent
    /// figure is the better guess and the older one was already wrong.
    ///
    /// A holding carrying no symbol is skipped rather than collapsed into a
    /// nameless instrument. No shipped build wrote one, but the column has a
    /// default now, so the case is representable.
    static func group(_ snapshots: [FundHoldingSnapshot]) -> [Group] {
        var groups: [String: [FundHoldingSnapshot]] = [:]
        var order: [String] = []

        for snapshot in snapshots {
            let key = snapshot.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !key.isEmpty else {
                continue
            }
            if groups[key] == nil {
                order.append(key)
            }
            groups[key, default: []].append(snapshot)
        }

        return order.compactMap { key in
            guard let members = groups[key], let first = members.first else {
                return nil
            }

            let oldest = members.min { $0.createdAt < $1.createdAt } ?? first
            let newestPriced = members.max { $0.navAsOf < $1.navAsOf } ?? first

            return Group(
                symbol: key,
                name: oldest.name.isEmpty ? key : oldest.name,
                kind: oldest.kind,
                pricePerUnit: newestPriced.currentNAVPerUnit,
                priceAsOf: newestPriced.navAsOf,
                currencyCode: oldest.currencyCode,
                createdAt: oldest.createdAt,
                holdingIDs: members.map(\.holdingID)
            )
        }
    }
}
