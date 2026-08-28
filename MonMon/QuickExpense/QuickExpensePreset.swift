import Foundation

enum QuickExpenseSlot: String, CaseIterable, Codable, Sendable {
    case coffee
    case lunch
    case fuel
}

enum QuickExpensePresetError: Error, Equatable, Sendable {
    case invalidSymbol
    case invalidAmount
    case incompleteSet
}

struct QuickExpensePreset: Codable, Equatable, Identifiable, Sendable {
    let slot: QuickExpenseSlot
    let symbol: String
    let amount: Decimal

    var id: QuickExpenseSlot { slot }

    init(slot: QuickExpenseSlot, symbol: String, amount: Decimal) throws {
        let normalizedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedSymbol.count == 1 else {
            throw QuickExpensePresetError.invalidSymbol
        }
        guard amount > 0 else {
            throw QuickExpensePresetError.invalidAmount
        }

        self.slot = slot
        self.symbol = normalizedSymbol
        self.amount = amount
    }

    static let defaults = [
        QuickExpensePreset(uncheckedSlot: .coffee, symbol: "☕", amount: 35_000),
        QuickExpensePreset(uncheckedSlot: .lunch, symbol: "🍜", amount: 50_000),
        QuickExpensePreset(uncheckedSlot: .fuel, symbol: "⛽", amount: 100_000),
    ]

    static func defaultPreset(for slot: QuickExpenseSlot) -> QuickExpensePreset {
        switch slot {
        case .coffee:
            QuickExpensePreset(uncheckedSlot: .coffee, symbol: "☕", amount: 35_000)
        case .lunch:
            QuickExpensePreset(uncheckedSlot: .lunch, symbol: "🍜", amount: 50_000)
        case .fuel:
            QuickExpensePreset(uncheckedSlot: .fuel, symbol: "⛽", amount: 100_000)
        }
    }

    private init(uncheckedSlot slot: QuickExpenseSlot, symbol: String, amount: Decimal) {
        self.slot = slot
        self.symbol = symbol
        self.amount = amount
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            slot: container.decode(QuickExpenseSlot.self, forKey: .slot),
            symbol: container.decode(String.self, forKey: .symbol),
            amount: container.decode(Decimal.self, forKey: .amount)
        )
    }
}

enum QuickExpenseWidgetConfiguration {
    static let kind = "QuickExpenseWidget"
    private static let appGroupInfoKey = "MonMonAppGroupIdentifier"

    static func appGroupIdentifier(in infoDictionary: [String: Any]) -> String? {
        guard
            let identifier = infoDictionary[appGroupInfoKey] as? String,
            !identifier.isEmpty
        else {
            return nil
        }
        return identifier
    }

    static func makeDefaults(bundle: Bundle = .main) -> UserDefaults {
        guard
            let identifier = appGroupIdentifier(in: bundle.infoDictionary ?? [:]),
            let defaults = UserDefaults(suiteName: identifier)
        else {
            return .standard
        }
        return defaults
    }
}

struct QuickExpensePresetStore {
    static let storageKey = "quickExpensePresets"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? QuickExpenseWidgetConfiguration.makeDefaults()
        encoder.outputFormatting = [.sortedKeys]
    }

    func load() -> [QuickExpensePreset] {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let decoded = try? decoder.decode([QuickExpensePreset].self, from: data),
            let normalized = try? normalize(decoded)
        else {
            return QuickExpensePreset.defaults
        }
        return normalized
    }

    func save(_ presets: [QuickExpensePreset]) throws {
        let normalized = try normalize(presets)
        defaults.set(try encoder.encode(normalized), forKey: Self.storageKey)
    }

    func preset(for slot: QuickExpenseSlot) -> QuickExpensePreset {
        load().first { $0.slot == slot }
            ?? QuickExpensePreset.defaultPreset(for: slot)
    }

    private func normalize(_ presets: [QuickExpensePreset]) throws -> [QuickExpensePreset] {
        guard presets.count == QuickExpenseSlot.allCases.count else {
            throw QuickExpensePresetError.incompleteSet
        }

        return try QuickExpenseSlot.allCases.map { slot in
            let matches = presets.filter { $0.slot == slot }
            guard matches.count == 1, let preset = matches.first else {
                throw QuickExpensePresetError.incompleteSet
            }
            return try QuickExpensePreset(
                slot: preset.slot,
                symbol: preset.symbol,
                amount: preset.amount
            )
        }
    }
}
