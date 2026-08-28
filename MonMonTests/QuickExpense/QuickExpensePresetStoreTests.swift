import AppIntents
import Foundation
import Testing

@testable import MonMon

@Suite("Quick expense presets")
struct QuickExpensePresetStoreTests {
    @Test("Missing storage returns nine defaults with three visible")
    func missingStorageReturnsDefaults() throws {
        let fixture = try makeFixture()

        let configuration = fixture.store.load()

        #expect(configuration == .defaults)
        #expect(configuration.visibleCount == .three)
        #expect(configuration.presets.count == 9)
        #expect(configuration.activePresets.map(\.slot) == [.coffee, .lunch, .fuel])
        #expect(configuration.activePresets.map(\.symbol) == ["☕", "🍜", "⛽"])
        #expect(configuration.activePresets.map(\.amount) == [35_000, 50_000, 100_000])
        #expect(
            configuration.presets.map(\.symbol) == ["☕", "🍜", "⛽", "🛒", "🅿️", "🚌", "💊", "🎬", "🧾"])
        #expect(
            configuration.presets.map(\.amount)
                == [35_000, 50_000, 100_000, 200_000, 20_000, 15_000, 100_000, 150_000, 500_000]
        )
    }

    @Test("A complete configuration round trips in slot order")
    func validSetRoundTrips() throws {
        let fixture = try makeFixture()
        let presets = try customizedPresets().reversed()

        try fixture.store.save(
            QuickExpenseConfiguration(visibleCount: .nine, presets: Array(presets))
        )

        let loaded = fixture.store.load()
        let expectedPresets = try customizedPresets()
        #expect(loaded.visibleCount == .nine)
        #expect(loaded.presets.map(\.slot) == QuickExpenseSlot.allCases)
        #expect(loaded.presets.map(\.symbol) == expectedPresets.map(\.symbol))
        #expect(loaded.activePresets.count == 9)
    }

    @Test("A legacy three-preset payload preserves custom values")
    func legacyPayloadMigrates() throws {
        let fixture = try makeFixture()
        let legacyPresets = [
            try QuickExpensePreset(slot: .fuel, symbol: "🚕", amount: 120_000),
            try QuickExpensePreset(slot: .coffee, symbol: "🧋", amount: 42_000),
            try QuickExpensePreset(slot: .lunch, symbol: "🥗", amount: 65_000),
        ]
        fixture.defaults.set(
            try JSONEncoder().encode(legacyPresets),
            forKey: QuickExpensePresetStore.storageKey
        )

        let migrated = fixture.store.load()

        #expect(migrated.visibleCount == .three)
        #expect(migrated.presets.count == 9)
        #expect(migrated.activePresets.map(\.symbol) == ["🧋", "🥗", "🚕"])
        #expect(migrated.activePresets.map(\.amount) == [42_000, 65_000, 120_000])
        #expect(
            Array(migrated.presets.dropFirst(3)) == Array(QuickExpensePreset.defaults.dropFirst(3)))
    }

    @Test("The supported counts expose active prefixes of three, six, and nine")
    func supportedCountsExposeActivePrefixes() {
        #expect(QuickExpensePresetCount.allCases.map(\.rawValue) == [3, 6, 9])
        #expect(
            QuickExpenseConfiguration(
                visibleCount: .six,
                presets: QuickExpensePreset.defaults
            ).activePresets.count == 6
        )
    }

    @Test("Reducing the visible count retains hidden presets")
    func hiddenPresetsAreRetained() throws {
        let fixture = try makeFixture()
        let presets = try customizedPresets()
        try fixture.store.save(QuickExpenseConfiguration(visibleCount: .nine, presets: presets))
        try fixture.store.save(QuickExpenseConfiguration(visibleCount: .three, presets: presets))

        let loaded = fixture.store.load()

        #expect(loaded.visibleCount == .three)
        #expect(loaded.activePresets.count == 3)
        #expect(loaded.presets == presets)
    }

    @Test("A preset requires exactly one visible symbol")
    func symbolValidation() {
        #expect(throws: QuickExpensePresetError.invalidSymbol) {
            try QuickExpensePreset(slot: .coffee, symbol: "", amount: 35_000)
        }
        #expect(throws: QuickExpensePresetError.invalidSymbol) {
            try QuickExpensePreset(slot: .coffee, symbol: "☕☕", amount: 35_000)
        }
        #expect(throws: QuickExpensePresetError.invalidSymbol) {
            try QuickExpensePreset(slot: .coffee, symbol: "C", amount: 35_000)
        }
    }

    @Test("A preset amount must be positive and whole")
    func amountValidation() {
        #expect(throws: QuickExpensePresetError.invalidAmount) {
            try QuickExpensePreset(slot: .coffee, symbol: "☕", amount: 0)
        }
        #expect(throws: QuickExpensePresetError.invalidAmount) {
            try QuickExpensePreset(slot: .coffee, symbol: "☕", amount: -1)
        }
        #expect(throws: QuickExpensePresetError.invalidAmount) {
            try QuickExpensePreset(slot: .coffee, symbol: "☕", amount: 35_000.5)
        }
    }

    @Test("Malformed storage recovers to defaults")
    func malformedStorageRecoversToDefaults() throws {
        let fixture = try makeFixture()
        fixture.defaults.set(Data("not-json".utf8), forKey: QuickExpensePresetStore.storageKey)

        #expect(fixture.store.load() == .defaults)
    }

    @Test("Saving requires one preset for every slot")
    func savingRequiresCompleteSet() throws {
        let fixture = try makeFixture()
        let coffee = try QuickExpensePreset(slot: .coffee, symbol: "☕", amount: 35_000)

        #expect(throws: QuickExpensePresetError.incompleteSet) {
            try fixture.store.save(
                QuickExpenseConfiguration(visibleCount: .three, presets: [coffee])
            )
        }
    }

    @Test("The intent dependency forwards the selected preset slot")
    func intentDependencyForwardsSlot() async throws {
        let recorder = SlotRecorder()
        let dependency = QuickExpenseIntentDependency { slot in
            await recorder.record(slot)
        }

        try await dependency.record(.lunch)

        #expect(await recorder.slots == [.lunch])
    }

    @Test("A successful quick expense intent provides user-visible feedback")
    func successfulIntentProvidesDialog() {
        requireDialog {
            try await RecordQuickExpenseIntent(slot: .coffee).perform()
        }
    }

    @Test("An editor draft round trips a localized VND amount")
    func editorDraftRoundTripsAmount() throws {
        let preset = try QuickExpensePreset(slot: .coffee, symbol: "☕", amount: 35_000)
        var draft = QuickExpensePresetDraft(preset: preset)

        draft.symbol = "🧋"
        draft.amountText = "42.000"

        #expect(try draft.makePreset().symbol == "🧋")
        #expect(try draft.makePreset().amount == 42_000)
    }

    @Test("An editor draft rejects an invalid amount")
    func editorDraftRejectsInvalidAmount() throws {
        let preset = try QuickExpensePreset(slot: .coffee, symbol: "☕", amount: 35_000)
        var draft = QuickExpensePresetDraft(preset: preset)
        draft.amountText = "35k"

        #expect(throws: QuickExpensePresetError.invalidAmount) {
            try draft.makePreset()
        }
    }

    private func makeFixture() throws -> Fixture {
        let suiteName = "QuickExpensePresetStoreTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return Fixture(defaults: defaults, store: QuickExpensePresetStore(defaults: defaults))
    }

    private func customizedPresets() throws -> [QuickExpensePreset] {
        try zip(QuickExpenseSlot.allCases, ["🧋", "🥗", "🚕", "🛍️", "🚙", "🚇", "🩹", "🎮", "📄"])
            .enumerated()
            .map { index, pair in
                try QuickExpensePreset(
                    slot: pair.0,
                    symbol: pair.1,
                    amount: Decimal((index + 1) * 10_000)
                )
            }
    }

    private func requireDialog<Result: IntentResult & ProvidesDialog>(
        _ operation: @escaping () async throws -> Result
    ) {}

    private struct Fixture {
        let defaults: UserDefaults
        let store: QuickExpensePresetStore
    }

    private actor SlotRecorder {
        private(set) var slots: [QuickExpenseSlot] = []

        func record(_ slot: QuickExpenseSlot) {
            slots.append(slot)
        }
    }
}
