import Foundation

struct SyncConflict: Identifiable, Sendable {
    var id: String
    var options: [SyncRecord?]
    var origins: [String]
    let optionIDs: [UUID]
    init(id: String, options: [SyncRecord?], origins: [String]) {
        self.id = id
        self.options = options
        self.origins = origins
        self.optionIDs = options.map { _ in UUID() }
    }
}

struct SyncChange: Identifiable, Sendable {
    var id: String
    var before: SyncRecord?
    var after: SyncRecord?
    var kind: String { before == nil ? "Added" : after == nil ? "Deleted" : "Updated" }
}

struct SyncMergePlan: Sendable {
    var automatic: [SyncRecord]
    var conflicts: [SyncConflict]
    var deletedSeeds: Set<String>
    var aliases: [String: String]
    var sourceRecords: [SyncRecord] = []

    func resolved(_ choices: [String: Int]) throws -> SyncSnapshot {
        var result = automatic
        var tombstones = deletedSeeds
        for conflict in conflicts {
            guard let choice = choices[conflict.id], conflict.options.indices.contains(choice)
            else {
                throw SyncError.unresolvedConflicts
            }
            if let record = conflict.options[choice] {
                result.append(record)
                tombstones.remove(record.id)
            } else if SyncSnapshot.isSeedKey(conflict.id) {
                tombstones.insert(conflict.id)
            }
        }
        for record in result { tombstones.remove(record.id) }
        let snapshot = SyncSnapshot(
            records: result.sorted { $0.id < $1.id }, deletedSeeds: tombstones, aliases: aliases)
        try snapshot.validateDeletions(from: sourceRecords)
        return snapshot
    }

    func finalized(_ choices: [String: Int]) throws -> SyncSnapshot {
        var target = try resolved(choices)
        let present = Set(target.records.map(\.id))
        for (type, ids) in SyncSnapshot.seedIDs {
            for uuid in ids {
                let key = type + "/" + uuid
                if key != SyncSnapshot.anchorID && !present.contains(key) {
                    target.deletedSeeds.insert(key)
                }
            }
        }
        _ = try target.validated()
        return target
    }

    func changes(from snapshot: SyncSnapshot, choices: [String: Int] = [:]) throws -> [SyncChange] {
        let result = try resolved(choices)
        let before = Dictionary(grouping: snapshot.records, by: \.id)
        let after = Dictionary(grouping: result.records, by: \.id)
        return Set(before.keys).union(after.keys).sorted().compactMap { id in
            let old = before[id]?.first
            let new = after[id]?.first
            guard old != new || (before[id]?.count ?? 0) > 1 else { return nil }
            return SyncChange(id: id, before: old, after: new)
        }
    }
}

enum SyncMergePlanner {
    static func plan(base: SyncSnapshot?, local: SyncSnapshot, remote: SyncSnapshot) throws
        -> SyncMergePlan
    {
        let all = (base?.records ?? []) + local.records + remote.records
        guard
            all.allSatisfy({
                SyncSnapshot.types.contains($0.type) && UUID(uuidString: $0.uuid) != nil
            })
        else {
            throw SyncError.invalidData
        }
        let establishedIDs = Set(base?.records.map(\.id) ?? [])
        let aliases = try identityAliases(
            (local.records + remote.records).filter { record in
                !establishedIDs.contains(record.id)
            },
            previous: (base?.aliases ?? [:]).merging(local.aliases) { a, _ in a }.merging(
                remote.aliases
            ) { a, _ in a })
        let a = Dictionary(grouping: local.records.map { remap($0, aliases: aliases) }, by: \.id)
        let b = Dictionary(grouping: remote.records.map { remap($0, aliases: aliases) }, by: \.id)
        let ancestor = Dictionary(
            grouping: (base?.records ?? []).map { remap($0, aliases: aliases) }, by: \.id)
        var result = SyncMergePlan(
            automatic: [], conflicts: [],
            deletedSeeds: local.deletedSeeds.union(remote.deletedSeeds).union(
                base?.deletedSeeds ?? []), aliases: aliases)
        let keys = Set(a.keys).union(b.keys).union(ancestor.keys)
        for key in keys.sorted() {
            let left = distinct(a[key] ?? [])
            let right = distinct(b[key] ?? [])
            let old = distinct(ancestor[key] ?? [])
            if left.count > 1 || right.count > 1 {
                var options = left.map(Optional.some) + right.map(Optional.some)
                var origins =
                    Array(repeating: "This device", count: left.count)
                    + Array(repeating: "Other device", count: right.count)
                if base == nil && SyncSnapshot.isSeedKey(key) && (left.isEmpty || right.isEmpty) {
                    options.append(nil)
                    origins.append(left.isEmpty ? "This device" : "Other device")
                }
                result.conflicts.append(
                    SyncConflict(
                        id: key, options: options,
                        origins: origins))
                continue
            }
            let l = left.first, r = right.first, o = old.first
            let forcedSeedDecision =
                base == nil && key != SyncSnapshot.anchorID && SyncSnapshot.isSeedKey(key)
                && (l == nil) != (r == nil)
            if !forcedSeedDecision && equivalent(l, r) {
                if let kept = canonical(l, r) { result.automatic.append(kept) }
            } else if !forcedSeedDecision && old.count <= 1 && base != nil && equivalent(l, o) {
                if let r {
                    result.automatic.append(r)
                } else if SyncSnapshot.isSeedKey(key) {
                    result.deletedSeeds.insert(key)
                }
            } else if !forcedSeedDecision && old.count <= 1 && base != nil && equivalent(r, o) {
                if let l {
                    result.automatic.append(l)
                } else if SyncSnapshot.isSeedKey(key) {
                    result.deletedSeeds.insert(key)
                }
            } else if !forcedSeedDecision && o == nil && (l == nil || r == nil)
                && !result.deletedSeeds.contains(key)
            {
                if let kept = l ?? r { result.automatic.append(kept) }
            } else {
                result.conflicts.append(
                    SyncConflict(
                        id: key, options: [l, r], origins: ["This device", "Other device"]))
            }
        }
        let sources =
            local.records.map { remap($0, aliases: aliases) }
            + remote.records.map { remap($0, aliases: aliases) }
        result.sourceRecords = sources
        let available = Dictionary(grouping: sources, by: \.id)
        let possibleChildren =
            result.automatic + result.conflicts.flatMap { $0.options.compactMap { $0 } }
        var represented = Set(result.automatic.map(\.id)).union(result.conflicts.map(\.id))
        let neededParents = possibleChildren.reduce(into: Set<String>()) { parents, record in
            parents.formUnion(SyncSnapshot.requiredParents(of: record))
        }
        for parentID in neededParents.sorted() {
            if !represented.contains(parentID), let parent = available[parentID]?.first {
                result.conflicts.append(
                    SyncConflict(
                        id: parentID, options: [parent, nil],
                        origins: ["Keep referenced item", "Delete / keep absent"]))
                represented.insert(parentID)
            }
        }
        return result
    }

    private static func equivalent(_ a: SyncRecord?, _ b: SyncRecord?) -> Bool {
        guard var a, var b else { return a == b }
        // Creation time describes provenance, not a user's concurrent edit.
        a.fields.removeValue(forKey: "createdAt")
        b.fields.removeValue(forKey: "createdAt")
        return a == b
    }

    private static func canonical(_ a: SyncRecord?, _ b: SyncRecord?) -> SyncRecord? {
        guard let a, let b else { return a ?? b }
        return (a.fields["createdAt"]?.text ?? "") <= (b.fields["createdAt"]?.text ?? "") ? a : b
    }

    private static func distinct(_ records: [SyncRecord]) -> [SyncRecord] {
        var result: [SyncRecord] = []
        for record in records.sorted(by: {
            ($0.fields["createdAt"]?.text ?? "") < ($1.fields["createdAt"]?.text ?? "")
        }) {
            if !result.contains(where: { equivalent($0, record) }) { result.append(record) }
        }
        return result
    }

    /// Only established domain identities fold. User-entered transactions never use a content fingerprint.
    private static func naturalKeys(_ r: SyncRecord) -> [String] {
        func text(_ key: String) -> String { r.fields[key]?.text ?? "" }
        switch r.type {
        case "categories":
            return [
                "category/" + text("kind") + "/"
                    + text("name").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            ]
        case "fundInstruments":
            return [
                "instrument/"
                    + text("symbol").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            ]
        case "tripWorkspaces":
            return text("sourceGoalID").isEmpty ? [] : ["trip/" + text("sourceGoalID")]
        case "transactions":
            if !text("sourceRuleID").isEmpty,
                let date = try? MonMonBackupScalar.parseDate(text("occurredAt")),
                let rule = UUID(uuidString: text("sourceRuleID"))
            {
                return ["recurring/" + RecurringGenerator.key(ruleID: rule, occurredAt: date)]
            }
            if !text("sourceImportID").isEmpty {
                return [
                    [
                        "import", text("sourceImportID"), text("kind"), text("amount"),
                        text("occurredAt"), text("accountID"), text("currencyCode"),
                    ].joined(separator: "/")
                ]
            }
            return []
        case "transfers":
            return ["sourceAccountImportID", "destinationAccountImportID"].compactMap { field in
                guard !text(field).isEmpty else { return nil }
                return
                    (["transfer", field, text(field)]
                    + [
                        "amount", "occurredAt", "sourceAccountID", "destinationAccountID",
                        "currencyCode",
                    ].map(text)).joined(separator: "/")
            }
        default: return []
        }
    }

    private static func identityAliases(_ records: [SyncRecord], previous: [String: String]) throws
        -> [String: String]
    {
        var parent = previous
        func root(_ key: String) throws -> String {
            var key = key
            var visited: Set<String> = []
            while let next = parent[key], next != key {
                guard visited.insert(key).inserted,
                    next.split(separator: "/").first == key.split(separator: "/").first
                else { throw SyncError.invalidData }
                key = next
            }
            return key
        }
        var natural: [String: String] = [:]
        // Existing aliases participate before natural identities, so old IDs never reappear.
        for record in records.sorted(by: { $0.id < $1.id }) {
            for key in naturalKeys(record) {
                let own = try root(record.id)
                if let other = natural[key] {
                    let target = try root(other)
                    if own != target {
                        let winner =
                            SyncSnapshot.isSeedKey(own)
                            ? own : SyncSnapshot.isSeedKey(target) ? target : min(own, target)
                        parent[own == winner ? target : own] = winner
                    }
                } else {
                    natural[key] = own
                }
            }
        }
        for key in Array(parent.keys) { parent[key] = try root(key) }
        return parent.filter { $0.key != $0.value }
    }

    static func remap(_ record: SyncRecord, aliases: [String: String]) -> SyncRecord {
        var result = record
        if let target = aliases[record.id] {
            result.fields["id"] = .string(String(target.split(separator: "/").last ?? ""))
        }
        let targets = SyncSnapshot.referenceTypes
        for (field, type) in targets {
            if let id = record.fields[field]?.text, let target = aliases[type + "/" + id] {
                result.fields[field] = .string(String(target.split(separator: "/").last ?? ""))
            }
        }
        return result
    }
}

extension SyncSnapshot {
    static func isSeedKey(_ key: String) -> Bool {
        let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
        return parts.count == 2 && seedIDs[parts[0]]?.contains(parts[1]) == true
    }
}
