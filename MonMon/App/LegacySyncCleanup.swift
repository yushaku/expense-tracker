import Foundation
import Security
import SwiftData

/// Removes what the retired peer-to-peer device sync left behind.
///
/// Two places held it: `sync/*` rows in `SyncMetadata` (the pairing state,
/// baseline snapshot and reports) and the pairing secret in Keychain. Both are
/// dead weight now, and the `sync/state` row in particular used to stop
/// `StoreReconciler` from folding duplicates.
///
/// Runs on every launch, before the store is seeded or reconciled, and costs a
/// single counted query once the store is clean. The Keychain sweep runs until
/// it succeeds once, then a defaults flag skips it. `seed/*` markers and every
/// financial record are left alone, as are the `p2p-recovery` files, which are
/// the owner's pre-sync copies of their data.
@MainActor
enum LegacySyncCleanup {
    static let keychainCleanedKey = "legacySync.keychainCleaned"

    struct Report: Equatable {
        var deletedMetadataRows = 0
        var cleanedKeychain = false
    }

    @discardableResult
    static func run(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        deleteKeychainItems: () -> Bool = LegacySyncKeychain.deleteAll
    ) throws -> Report {
        var report = Report()
        let isSyncKey = #Predicate<SyncMetadata> { $0.key.starts(with: "sync/") }
        if try context.fetchCount(FetchDescriptor(predicate: isSyncKey)) > 0 {
            let rows = try context.fetch(FetchDescriptor(predicate: isSyncKey))
            for row in rows { context.delete(row) }
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
            report.deletedMetadataRows = rows.count
        }
        if !defaults.bool(forKey: keychainCleanedKey), deleteKeychainItems() {
            defaults.set(true, forKey: keychainCleanedKey)
            report.cleanedKeychain = true
        }
        return report
    }
}

/// The Keychain items the device sync stored its pairing secrets under: one
/// generic password per pairing, all under one service per build flavour.
enum LegacySyncKeychain {
    static var service: String { "monmon.p2p." + MonMonBackupFlavour.current.rawValue }

    /// True when nothing is left, including when nothing was ever there.
    static func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
