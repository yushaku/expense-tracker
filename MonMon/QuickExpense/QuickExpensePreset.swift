import Foundation

enum QuickExpenseSlot: String, CaseIterable, Codable, Sendable {
    case coffee
    case lunch
    case fuel
    case groceries
    case parking
    case transit
    case medicine
    case entertainment
    case bills
}

enum QuickExpensePresetCount: Int, CaseIterable, Codable, Identifiable, Sendable {
    case three = 3
    case six = 6
    case nine = 9

    var id: Int { rawValue }
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
        let containsEmojiPresentation = normalizedSymbol.unicodeScalars.contains {
            $0.properties.isEmojiPresentation || $0.value == 0xFE0F
        }
        guard normalizedSymbol.count == 1, containsEmojiPresentation else {
            throw QuickExpensePresetError.invalidSymbol
        }
        var amountToRound = amount
        var roundedAmount = Decimal()
        NSDecimalRound(&roundedAmount, &amountToRound, 0, .plain)
        guard amount > 0, amount == roundedAmount else {
            throw QuickExpensePresetError.invalidAmount
        }

        self.slot = slot
        self.symbol = normalizedSymbol
        self.amount = amount
    }

    static let defaults = QuickExpenseSlot.allCases.map(defaultPreset(for:))

    static func defaultPreset(for slot: QuickExpenseSlot) -> QuickExpensePreset {
        switch slot {
        case .coffee:
            QuickExpensePreset(uncheckedSlot: .coffee, symbol: "☕", amount: 35_000)
        case .lunch:
            QuickExpensePreset(uncheckedSlot: .lunch, symbol: "🍜", amount: 50_000)
        case .fuel:
            QuickExpensePreset(uncheckedSlot: .fuel, symbol: "⛽", amount: 100_000)
        case .groceries:
            QuickExpensePreset(uncheckedSlot: .groceries, symbol: "🛒", amount: 200_000)
        case .parking:
            QuickExpensePreset(uncheckedSlot: .parking, symbol: "🅿️", amount: 20_000)
        case .transit:
            QuickExpensePreset(uncheckedSlot: .transit, symbol: "🚌", amount: 15_000)
        case .medicine:
            QuickExpensePreset(uncheckedSlot: .medicine, symbol: "💊", amount: 100_000)
        case .entertainment:
            QuickExpensePreset(uncheckedSlot: .entertainment, symbol: "🎬", amount: 150_000)
        case .bills:
            QuickExpensePreset(uncheckedSlot: .bills, symbol: "🧾", amount: 500_000)
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

struct QuickExpenseConfiguration: Codable, Equatable, Sendable {
    let visibleCount: QuickExpensePresetCount
    let presets: [QuickExpensePreset]

    var activePresets: [QuickExpensePreset] {
        Array(presets.prefix(visibleCount.rawValue))
    }

    static let defaults = QuickExpenseConfiguration(
        visibleCount: .three,
        presets: QuickExpensePreset.defaults
    )
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

    func load() -> QuickExpenseConfiguration {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return .defaults
        }

        if let decoded = try? decoder.decode(QuickExpenseConfiguration.self, from: data),
            let normalized = try? normalize(decoded)
        {
            return normalized
        }

        if let legacyPresets = try? decoder.decode([QuickExpensePreset].self, from: data),
            let migrated = try? migrate(legacyPresets)
        {
            return migrated
        }

        return .defaults
    }

    func save(_ configuration: QuickExpenseConfiguration) throws {
        let normalized = try normalize(configuration)
        defaults.set(try encoder.encode(normalized), forKey: Self.storageKey)
    }

    func preset(for slot: QuickExpenseSlot) -> QuickExpensePreset {
        load().presets.first { $0.slot == slot }
            ?? QuickExpensePreset.defaultPreset(for: slot)
    }

    private func normalize(
        _ configuration: QuickExpenseConfiguration
    ) throws -> QuickExpenseConfiguration {
        QuickExpenseConfiguration(
            visibleCount: configuration.visibleCount,
            presets: try normalizePresets(configuration.presets)
        )
    }

    private func normalizePresets(_ presets: [QuickExpensePreset]) throws -> [QuickExpensePreset] {
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

    private func migrate(_ legacyPresets: [QuickExpensePreset]) throws -> QuickExpenseConfiguration
    {
        let legacySlots: [QuickExpenseSlot] = [.coffee, .lunch, .fuel]
        guard legacyPresets.count == legacySlots.count else {
            throw QuickExpensePresetError.incompleteSet
        }

        var migratedPresets = QuickExpensePreset.defaults
        for slot in legacySlots {
            let matches = legacyPresets.filter { $0.slot == slot }
            guard matches.count == 1, let preset = matches.first else {
                throw QuickExpensePresetError.incompleteSet
            }
            let index = try requiredIndex(for: slot)
            migratedPresets[index] = try QuickExpensePreset(
                slot: preset.slot,
                symbol: preset.symbol,
                amount: preset.amount
            )
        }

        return QuickExpenseConfiguration(visibleCount: .three, presets: migratedPresets)
    }

    private func requiredIndex(for slot: QuickExpenseSlot) throws -> Int {
        guard let index = QuickExpenseSlot.allCases.firstIndex(of: slot) else {
            throw QuickExpensePresetError.incompleteSet
        }
        return index
    }
}
