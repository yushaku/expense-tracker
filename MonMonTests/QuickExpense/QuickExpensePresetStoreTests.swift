import Foundation
import Testing

@testable import MonMon

@Suite("Quick expense presets")
struct QuickExpensePresetStoreTests {
    @Test("Missing storage returns the three requested defaults")
    func missingStorageReturnsDefaults() throws {
        let fixture = try makeFixture()

        let presets = fixture.store.load()

        #expect(presets == QuickExpensePreset.defaults)
        #expect(presets.map(\.slot) == [.coffee, .lunch, .fuel])
        #expect(presets.map(\.symbol) == ["☕", "🍜", "⛽"])
        #expect(presets.map(\.amount) == [35_000, 50_000, 100_000])
    }

    @Test("A complete valid set round trips in slot order")
    func validSetRoundTrips() throws {
        let fixture = try makeFixture()
        let presets = [
            try QuickExpensePreset(slot: .fuel, symbol: "🚕", amount: 120_000),
            try QuickExpensePreset(slot: .coffee, symbol: "🧋", amount: 42_000),
            try QuickExpensePreset(slot: .lunch, symbol: "🥗", amount: 65_000),
        ]

        try fixture.store.save(presets)

        #expect(fixture.store.load().map(\.slot) == [.coffee, .lunch, .fuel])
        #expect(fixture.store.load().map(\.symbol) == ["🧋", "🥗", "🚕"])
        #expect(fixture.store.load().map(\.amount) == [42_000, 65_000, 120_000])
    }

    @Test("A preset requires exactly one visible symbol")
    func symbolValidation() {
        #expect(throws: QuickExpensePresetError.invalidSymbol) {
            try QuickExpensePreset(slot: .coffee, symbol: "", amount: 35_000)
        }
        #expect(throws: QuickExpensePresetError.invalidSymbol) {
            try QuickExpensePreset(slot: .coffee, symbol: "☕☕", amount: 35_000)
        }
    }

    @Test("A preset amount must be positive")
    func amountValidation() {
        #expect(throws: QuickExpensePresetError.invalidAmount) {
            try QuickExpensePreset(slot: .coffee, symbol: "☕", amount: 0)
        }
        #expect(throws: QuickExpensePresetError.invalidAmount) {
            try QuickExpensePreset(slot: .coffee, symbol: "☕", amount: -1)
        }
    }

    @Test("Malformed storage recovers to defaults")
    func malformedStorageRecoversToDefaults() throws {
        let fixture = try makeFixture()
        fixture.defaults.set(Data("not-json".utf8), forKey: QuickExpensePresetStore.storageKey)

        #expect(fixture.store.load() == QuickExpensePreset.defaults)
    }

    @Test("Saving requires one preset for every slot")
    func savingRequiresCompleteSet() throws {
        let fixture = try makeFixture()
        let coffee = try QuickExpensePreset(slot: .coffee, symbol: "☕", amount: 35_000)

        #expect(throws: QuickExpensePresetError.incompleteSet) {
            try fixture.store.save([coffee])
        }
    }

    private func makeFixture() throws -> Fixture {
        let suiteName = "QuickExpensePresetStoreTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return Fixture(defaults: defaults, store: QuickExpensePresetStore(defaults: defaults))
    }

    private struct Fixture {
        let defaults: UserDefaults
        let store: QuickExpensePresetStore
    }
}
