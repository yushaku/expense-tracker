import Foundation

/// Preferences are never exchanged. Only this device's references follow an
/// explicitly merged identity; a deleted selection becomes unselected.
@MainActor
enum SyncLocalReferences {
    static func reconcile(
        _ snapshot: SyncSnapshot, defaults: UserDefaults = .standard,
        presets: QuickExpensePresetStore = QuickExpensePresetStore()
    ) throws {
        let accounts = Set(snapshot.records.filter { $0.type == "accounts" }.map(\.uuid))
        let categories = Set(snapshot.records.filter { $0.type == "categories" }.map(\.uuid))
        func mapped(_ raw: String?, type: String, valid: Set<String>) -> String? {
            guard let raw, let uuid = UUID(uuidString: raw) else { return nil }
            let old = uuid.uuidString.lowercased()
            let replacement =
                snapshot.aliases[type + "/" + old]?.split(separator: "/").last.map(String.init)
                ?? old
            return valid.contains(replacement) ? UUID(uuidString: replacement)?.uuidString : nil
        }
        for key in [
            TransactionDefaults.accountStorageKey, TransactionDefaults.categoryStorageKey,
            TransactionDefaults.incomeCategoryStorageKey,
        ] {
            guard let old = defaults.string(forKey: key), !old.isEmpty else { continue }
            let isAccount = key == TransactionDefaults.accountStorageKey
            if let new = mapped(
                old, type: isAccount ? "accounts" : "categories",
                valid: isAccount ? accounts : categories)
            {
                if new != old { defaults.set(new, forKey: key) }
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        if let old = defaults.dictionary(forKey: StatementAccountMapping.storageKey)
            as? [String: String]
        {
            let updated = old.compactMapValues { mapped($0, type: "accounts", valid: accounts) }
            if old != updated { defaults.set(updated, forKey: StatementAccountMapping.storageKey) }
        }
        let old = presets.load()
        let updated = try old.presets.map { preset in
            try QuickExpensePreset(
                slot: preset.slot, symbol: preset.symbol, amount: preset.amount,
                categoryID: mapped(
                    preset.categoryID?.uuidString, type: "categories", valid: categories
                ).flatMap(UUID.init(uuidString:)))
        }
        if old.presets != updated {
            try presets.save(
                QuickExpenseConfiguration(visibleCount: old.visibleCount, presets: updated))
        }
    }
}
