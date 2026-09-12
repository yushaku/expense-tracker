import CryptoKit
import Foundation

enum SyncError: Error, Equatable, LocalizedError {
    case unresolvedConflicts, invalidData, stalePreview, incompatiblePeer, notPaired
    case sessionPending, backupFailed, disconnected, tooLarge, invalidPairing, missingReferences

    var errorDescription: String? {
        switch self {
        case .unresolvedConflicts:
            return AppText.string(
                "Choose a version for every conflict before syncing.", in: AppLanguage.stored.locale
            )
        case .invalidData:
            return AppText.string(
                "Sync data is invalid. No changes were applied.", in: AppLanguage.stored.locale)
        case .stalePreview:
            return AppText.string(
                "Data changed since the preview. Start sync again to review it.",
                in: AppLanguage.stored.locale)
        case .incompatiblePeer:
            return AppText.string(
                "The devices need the same MonMon flavour and sync version.",
                in: AppLanguage.stored.locale)
        case .notPaired:
            return AppText.string("Pair these devices first.", in: AppLanguage.stored.locale)
        case .sessionPending:
            return AppText.string(
                "Reconnect to finish the pending sync first.", in: AppLanguage.stored.locale)
        case .backupFailed:
            return AppText.string(
                "Could not save a recovery backup. Sync has stopped.", in: AppLanguage.stored.locale
            )
        case .disconnected:
            return AppText.string(
                "Connection interrupted. Reconnect both devices to continue.",
                in: AppLanguage.stored.locale)
        case .tooLarge:
            return AppText.string(
                "Sync data exceeds the 100 MiB limit.", in: AppLanguage.stored.locale)
        case .invalidPairing:
            return AppText.string(
                "The pairing code is invalid or belongs to another MonMon flavour.",
                in: AppLanguage.stored.locale)
        case .missingReferences:
            return AppText.string(
                "Some retained records need an item marked for deletion. Keep that item or change your choices.",
                in: AppLanguage.stored.locale)
        }
    }
}

/// Canonical JSON values reuse the backup's string representation of money and UUIDs.
indirect enum SyncValue: Codable, Equatable, Sendable {
    case string(String), number(Decimal), bool(Bool), array([SyncValue]), object(
        [String: SyncValue]), null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() {
            self = .null
        } else if let v = try? value.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? value.decode(String.self) {
            self = .string(v)
        } else if let v = try? value.decode(Decimal.self) {
            self = .number(v)
        } else if let v = try? value.decode([SyncValue].self) {
            self = .array(v)
        } else {
            self = .object(try value.decode([String: SyncValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let v): try value.encode(v)
        case .number(let v): try value.encode(v)
        case .bool(let v): try value.encode(v)
        case .array(let v): try value.encode(v)
        case .object(let v): try value.encode(v)
        case .null: try value.encodeNil()
        }
    }

    var text: String? {
        if case .string(let v) = self { return v }
        return nil
    }
}

struct SyncRecord: Codable, Equatable, Sendable, Identifiable {
    var type: String
    var fields: [String: SyncValue]
    var uuid: String { fields["id"]?.text ?? "" }
    var id: String { type + "/" + uuid }
    var title: String {
        fields["name"]?.text ?? fields["note"]?.text ?? fields["symbol"]?.text ?? uuid
    }
    var isSeed: Bool { SyncSnapshot.seedIDs[type]?.contains(uuid) == true }
}

struct SyncSnapshot: Codable, Equatable, Sendable {
    static let types = [
        "accounts", "savingsDeposits", "savingsWithdrawals", "fundInstruments",
        "fundHoldings", "fundSales", "budgetJars", "goals", "tripWorkspaces", "categories",
        "transactions", "transfers", "debts", "debtPayments", "recurringRules",
    ]
    static let seedIDs: [String: Set<String>] = [
        "accounts": Set([1, 2].map { String(format: "00000000-0000-0000-0000-%012x", $0) }),
        "categories": Set(
            (1...10).map { String(format: "00000000-0000-0000-0000-0000000001%02x", $0) }),
        "budgetJars": Set(
            (1...6).map { String(format: "00000000-0000-0000-0000-0000000003%02x", $0) }),
    ]
    static let anchorID = "accounts/00000000-0000-0000-0000-000000000001"
    static let empty = SyncSnapshot(records: [])
    var records: [SyncRecord]
    var deletedSeeds: Set<String> = []
    var aliases: [String: String] = [:]

    init(records: [SyncRecord], deletedSeeds: Set<String> = [], aliases: [String: String] = [:]) {
        self.records = records
        self.deletedSeeds = deletedSeeds
        self.aliases = aliases
    }

    init(payload: MonMonBackupPayload, deletedSeeds: Set<String> = []) throws {
        let root = try JSONDecoder().decode(
            [String: SyncValue].self, from: SyncCoding.encode(payload))
        records = try Self.types.flatMap { type -> [SyncRecord] in
            guard case .array(let values) = root[type] else { throw SyncError.invalidData }
            return try values.map {
                guard case .object(let fields) = $0 else { throw SyncError.invalidData }
                return SyncRecord(type: type, fields: fields)
            }
        }
        self.deletedSeeds = deletedSeeds
    }

    func payload() throws -> MonMonBackupPayload {
        var root = try JSONDecoder().decode(
            [String: SyncValue].self, from: SyncCoding.encode(MonMonBackupPayload.empty))
        for type in Self.types {
            root[type] = .array(records.filter { $0.type == type }.map { .object($0.fields) })
        }
        return try JSONDecoder().decode(MonMonBackupPayload.self, from: SyncCoding.encode(root))
            .sorted()
    }

    func validated() throws -> MonMonBackupPayload {
        guard Set(records.map(\.id)).count == records.count,
            records.allSatisfy({ Self.types.contains($0.type) && UUID(uuidString: $0.uuid) != nil })
        else { throw SyncError.invalidData }
        let payload = try payload()
        let document = try MonMonBackupDocument.make(
            payload: payload, exportedAt: .now, appVersion: "p2p-v1", flavour: .current)
        let validated = try MonMonBackupValidator.validate(document)
        // Existing optional provenance (for example a deleted recurring rule)
        // may legitimately be absent. The merge planner separately prevents
        // introducing dangling relationships by deleting a still-needed parent.
        let roundTrip = try SyncSnapshot(payload: validated.payload)
        guard
            roundTrip.records.sorted(by: { $0.id < $1.id }) == records.sorted(by: { $0.id < $1.id })
        else { throw SyncError.invalidData }
        return validated.payload
    }

    static let referenceTypes: [String: String] = [
        "swapHoldingID": "fundHoldings",
        "accountID": "accounts", "sourceAccountID": "accounts", "destinationAccountID": "accounts",
        "proceedsAccountID": "accounts", "categoryID": "categories", "budgetJarID": "budgetJars",
        "budgetJarOverrideID": "budgetJars", "fundingJarID": "budgetJars",
        "instrumentID": "fundInstruments",
        "holdingID": "fundHoldings", "depositID": "savingsDeposits", "debtID": "debts",
        "sourceRuleID": "recurringRules", "sourceGoalID": "goals",
        "tripWorkspaceID": "tripWorkspaces",
    ]

    static func requiredParents(of record: SyncRecord) -> Set<String> {
        Set(
            referenceTypes.compactMap { field, type in
                // These identifiers retain provenance even after the originating
                // rule or goal is removed; they are not ownership relationships.
                guard field != "sourceRuleID", field != "sourceGoalID",
                    let id = record.fields[field]?.text
                else { return nil }
                return type + "/" + id
            })
    }

    func validateDeletions(from previous: [SyncRecord]) throws {
        let oldIDs = Set(previous.map(\.id))
        let newIDs = Set(records.map(\.id))
        let removed = oldIDs.subtracting(newIDs)
        for record in records where !Self.requiredParents(of: record).isDisjoint(with: removed) {
            throw SyncError.missingReferences
        }
    }

    func digest() throws -> String {
        let sorted = records.sorted {
            if $0.id != $1.id { return $0.id < $1.id }
            return ((try? SyncCoding.encode($0)) ?? Data()).lexicographicallyPrecedes(
                (try? SyncCoding.encode($1)) ?? Data())
        }
        return try SyncCoding.digest(
            SnapshotDigest(records: sorted, deletedSeeds: deletedSeeds.sorted(), aliases: aliases))
    }

    private struct SnapshotDigest: Codable {
        var records: [SyncRecord]
        var deletedSeeds: [String]
        var aliases: [String: String]
    }
}

enum SyncCoding {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    static func digest<T: Encodable>(_ value: T) throws -> String {
        SHA256.hash(data: try encode(value)).map { String(format: "%02x", $0) }.joined()
    }
}
