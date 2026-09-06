import Foundation
import Testing

@testable import MonMon

@Suite("P2P merge")
struct SyncMergeTests {
    private let first = UUID(uuid: (16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let second = UUID(uuid: (16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))

    private func record(_ id: UUID, note: String = "Lunch", type: String = "transactions")
        -> SyncRecord
    {
        SyncRecord(
            type: type,
            fields: [
                "id": .string(id.uuidString.lowercased()), "note": .string(note),
                "createdAt": .string("2026-01-01T00:00:00.000Z"),
            ])
    }

    @Test("First sync unions independent transactions and a repeat is empty")
    func unionAndRepeat() throws {
        let a = SyncSnapshot(records: [record(first)])
        let b = SyncSnapshot(records: [record(second)])
        let plan = try SyncMergePlanner.plan(base: nil, local: a, remote: b)
        #expect(plan.conflicts.isEmpty)
        let result = try plan.resolved([:])
        #expect(result.records.count == 2)
        let again = try SyncMergePlanner.plan(base: result, local: result, remote: result)
        #expect(try again.changes(from: result).isEmpty)
    }

    @Test("An offline deletion propagates without resurrecting the record")
    func deletion() throws {
        let base = SyncSnapshot(records: [record(first)])
        let plan = try SyncMergePlanner.plan(base: base, local: .empty, remote: base)
        #expect(try plan.resolved([:]).records.isEmpty)
    }

    @Test("Concurrent edits require an explicit choice, independent of clocks")
    func conflict() throws {
        let base = SyncSnapshot(records: [record(first)])
        let a = SyncSnapshot(records: [record(first, note: "Phone")])
        let b = SyncSnapshot(records: [record(first, note: "Mac")])
        let plan = try SyncMergePlanner.plan(base: base, local: a, remote: b)
        let conflict = try #require(plan.conflicts.first)
        #expect(throws: SyncError.unresolvedConflicts) { try plan.resolved([:]) }
        #expect(try plan.resolved([conflict.id: 1]).records.first?.fields["note"] == .string("Mac"))
    }

    @Test("A seed absent on one side of the first sync requires a decision")
    func missingSeed() throws {
        let seed = record(AccountSeed.defaultBankID, type: "accounts")
        let plan = try SyncMergePlanner.plan(
            base: nil, local: SyncSnapshot(records: [seed]), remote: .empty)
        let conflict = try #require(plan.conflicts.first)
        #expect(try plan.resolved([conflict.id: 1]).records.isEmpty)
    }

    @Test("Same seeded ID in two languages creates one conflict, never two rows")
    func seedLanguages() throws {
        let a = record(AccountSeed.defaultBankID, note: "Bank", type: "accounts")
        let b = record(AccountSeed.defaultBankID, note: "Ngân hàng", type: "accounts")
        let plan = try SyncMergePlanner.plan(
            base: nil, local: SyncSnapshot(records: [a]), remote: SyncSnapshot(records: [b]))
        let conflict = try #require(plan.conflicts.first)
        #expect(try plan.resolved([conflict.id: 0]).records.count == 1)
    }

    @Test("Edit versus deletion remains a conflict")
    func editDelete() throws {
        let base = SyncSnapshot(records: [record(first)])
        let changed = SyncSnapshot(records: [record(first, note: "Changed")])
        let plan = try SyncMergePlanner.plan(base: base, local: changed, remote: .empty)
        #expect(plan.conflicts.count == 1)
    }

    @Test("Physical duplicate IDs with different values are not silently discarded")
    func physicalDuplicates() throws {
        let a = SyncSnapshot(records: [record(first), record(first, note: "Changed")])
        let plan = try SyncMergePlanner.plan(base: nil, local: a, remote: .empty)
        #expect(plan.conflicts.count == 1)
        #expect(try plan.resolved([plan.conflicts[0].id: 0]).records.count == 1)
    }
    @Test("A remotely added child makes its deleted parent an explicit decision")
    func deleteParentWithNewChild() throws {
        let parent = record(first, type: "categories")
        var child = record(second)
        child.fields["categoryID"] = .string(first.uuidString.lowercased())
        let base = SyncSnapshot(records: [parent])
        let remote = SyncSnapshot(records: [parent, child])
        let plan = try SyncMergePlanner.plan(base: base, local: .empty, remote: remote)
        let conflict = try #require(plan.conflicts.first)
        #expect(conflict.id == parent.id)
        #expect(throws: SyncError.missingReferences) { try plan.resolved([conflict.id: 1]) }
        #expect(try plan.resolved([conflict.id: 0]).records.count == 2)
    }

    @Test("Old names in the baseline do not merge unrelated current categories")
    func historicalNamesAreNotIdentity() throws {
        var oldA = record(first, type: "categories")
        oldA.fields["name"] = .string("Old")
        var newA = oldA
        newA.fields["name"] = .string("Renamed")
        var newB = record(second, type: "categories")
        newB.fields["name"] = .string("Old")
        let base = SyncSnapshot(records: [oldA])
        let local = SyncSnapshot(records: [newA, newB])
        let remote = SyncSnapshot(records: [newA])
        let result = try SyncMergePlanner.plan(base: base, local: local, remote: remote).resolved(
            [:])
        #expect(result.records.count == 2)
    }

    @Test("Renaming established categories never changes their identities")
    func establishedCategoryNames() throws {
        var a = record(first, type: "categories")
        a.fields["name"] = .string("Food")
        var b = record(second, type: "categories")
        b.fields["name"] = .string("Travel")
        let base = SyncSnapshot(records: [a, b])
        a.fields["name"] = .string("Dining")
        b.fields["name"] = .string("Food")
        let result = try SyncMergePlanner.plan(
            base: base, local: SyncSnapshot(records: [a, b]), remote: base
        ).resolved([:])
        #expect(result.records.count == 2)
        #expect(result.aliases.isEmpty)
        #expect(Set(result.records.map(\.id)) == Set(base.records.map(\.id)))
    }

    @Test("A retained crypto swap cannot lose its received holding")
    func swapHoldingDeletion() throws {
        let holding = record(first, type: "fundHoldings")
        var sale = record(second, type: "fundSales")
        sale.fields["swapHoldingID"] = .string(first.uuidString.lowercased())
        let base = SyncSnapshot(records: [holding])
        let plan = try SyncMergePlanner.plan(
            base: base, local: .empty, remote: SyncSnapshot(records: [holding, sale]))
        let conflict = try #require(plan.conflicts.first)
        #expect(conflict.id == holding.id)
        #expect(throws: SyncError.missingReferences) { try plan.resolved([conflict.id: 1]) }
        #expect(try plan.resolved([conflict.id: 0]).records.count == 2)
        let alias = [holding.id: "fundHoldings/" + second.uuidString.lowercased()]
        #expect(
            SyncMergePlanner.remap(sale, aliases: alias).fields["swapHoldingID"]
                == .string(second.uuidString.lowercased()))
    }

    @Test("An absent seed can be deleted even when its other copy has physical duplicates")
    func duplicateSeedAbsent() throws {
        let seed = record(AccountSeed.defaultBankID, type: "accounts")
        var duplicate = seed
        duplicate.fields["note"] = .string("Different")
        let plan = try SyncMergePlanner.plan(
            base: nil, local: SyncSnapshot(records: [seed, duplicate]), remote: .empty)
        let conflict = try #require(plan.conflicts.first)
        let missing = try #require(conflict.options.firstIndex(where: { $0 == nil }))
        #expect(try plan.resolved([conflict.id: missing]).records.isEmpty)
    }

    @Test("Recurring occurrences have the same ID on both devices for the same rule and day")
    func recurringIdentity() throws {
        let morning = try MonMonBackupScalar.parseDate("2026-01-01T01:00:00.000Z")
        let later = morning.addingTimeInterval(60)
        #expect(
            RecurringGenerator.occurrenceID(ruleID: first, occurredAt: morning)
                == RecurringGenerator.occurrenceID(ruleID: first, occurredAt: later))
        #expect(
            RecurringGenerator.occurrenceID(ruleID: first, occurredAt: morning)
                != RecurringGenerator.occurrenceID(ruleID: second, occurredAt: morning))
    }

}
