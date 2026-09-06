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
        #expect(configuration.visibleCount == 3)
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
            QuickExpenseConfiguration(visibleCount: 9, presets: Array(presets))
        )

        let loaded = fixture.store.load()
        let expectedPresets = try customizedPresets()
        #expect(loaded.visibleCount == 9)
        #expect(loaded.presets.map(\.slot) == QuickExpenseSlot.allCases)
        #expect(loaded.presets.map(\.symbol) == expectedPresets.map(\.symbol))
        #expect(loaded.activePresets.count == 9)
    }

    @Test("A configured category round trips without changing preset order")
    func configuredCategoryRoundTrips() throws {
        let fixture = try makeFixture()
        let categoryID = UUID()
        var presets = QuickExpensePreset.defaults
        presets[0] = try QuickExpensePreset(
            slot: .coffee,
            symbol: "☕",
            amount: 35_000,
            categoryID: categoryID
        )

        try fixture.store.save(
            QuickExpenseConfiguration(visibleCount: 3, presets: presets)
        )

        #expect(fixture.store.load().presets[0].categoryID == categoryID)
        #expect(fixture.store.load().presets.dropFirst().allSatisfy { $0.categoryID == nil })
    }

    @Test("A legacy three-preset payload preserves custom values")
    func legacyPayloadMigrates() throws {
        let fixture = try makeFixture()
        let legacyPresets = [
            LegacyPreset(slot: .fuel, symbol: "🚕", amount: 120_000),
            LegacyPreset(slot: .coffee, symbol: "🧋", amount: 42_000),
            LegacyPreset(slot: .lunch, symbol: "🥗", amount: 65_000),
        ]
        fixture.defaults.set(
            try JSONEncoder().encode(legacyPresets),
            forKey: QuickExpensePresetStore.storageKey
        )

        let migrated = fixture.store.load()

        #expect(migrated.visibleCount == 3)
        #expect(migrated.presets.count == 9)
        #expect(migrated.activePresets.map(\.symbol) == ["🧋", "🥗", "🚕"])
        #expect(migrated.activePresets.map(\.amount) == [42_000, 65_000, 120_000])
        #expect(migrated.presets.allSatisfy { $0.categoryID == nil })
        #expect(
            Array(migrated.presets.dropFirst(3)) == Array(QuickExpensePreset.defaults.dropFirst(3)))
    }

    @Test("The supported counts expose active prefixes of three, six, and nine")
    func supportedCountsExposeActivePrefixes() {
        #expect(QuickExpenseConfiguration.countRange == 1...9)
        #expect(
            QuickExpenseConfiguration(
                visibleCount: 6,
                presets: QuickExpensePreset.defaults
            ).activePresets.count == 6
        )
    }

    @Test("Reducing the visible count retains hidden presets")
    func hiddenPresetsAreRetained() throws {
        let fixture = try makeFixture()
        let presets = try customizedPresets()
        try fixture.store.save(QuickExpenseConfiguration(visibleCount: 9, presets: presets))
        try fixture.store.save(QuickExpenseConfiguration(visibleCount: 3, presets: presets))

        let loaded = fixture.store.load()

        #expect(loaded.visibleCount == 3)
        #expect(loaded.activePresets.count == 3)
        #expect(loaded.presets == presets)
    }

    @Test("Saving one preset preserves newer settings and hidden presets")
    func savingOnePresetPreservesOtherSettings() throws {
        let fixture = try makeFixture()
        let presets = try customizedPresets()
        try fixture.store.save(QuickExpenseConfiguration(visibleCount: 9, presets: presets))
        var draft = QuickExpensePresetDraft(preset: presets[0])
        draft.symbol = "Coffee"
        draft.categoryID = UUID()

        try fixture.store.setVisibleCount(3)
        try fixture.store.savePreset(draft.makePreset())

        let loaded = fixture.store.load()
        #expect(loaded.visibleCount == 3)
        #expect(loaded.presets[0] == (try draft.makePreset()))
        #expect(Array(loaded.presets.dropFirst()) == Array(presets.dropFirst()))
        try fixture.store.setVisibleCount(9)
        #expect(fixture.store.load().presets == loaded.presets)
    }

    @Test("Editing a local draft leaves storage unchanged until save")
    func draftDoesNotWriteUntilSaved() throws {
        let fixture = try makeFixture()
        let original = fixture.store.load()
        var draft = QuickExpensePresetDraft(preset: original.presets[0])
        draft.amountText = "0"
        draft.symbol = "Changed"

        #expect(throws: QuickExpensePresetError.invalidAmount) {
            try fixture.store.savePreset(draft.makePreset())
        }
        #expect(fixture.store.load() == original)
    }

    @Test("A preset requires a short nonempty name")
    func nameValidation() throws {
        #expect(throws: QuickExpensePresetError.invalidName) {
            try QuickExpensePreset(slot: .coffee, symbol: "", amount: 35_000)
        }
        #expect(throws: QuickExpensePresetError.invalidName) {
            try QuickExpensePreset(slot: .coffee, symbol: "   ", amount: 35_000)
        }
        #expect(throws: QuickExpensePresetError.invalidName) {
            try QuickExpensePreset(slot: .coffee, symbol: "12345678901234567", amount: 35_000)
        }

        #expect(
            try QuickExpensePreset(slot: .coffee, symbol: "  Morning coffee  ", amount: 35_000)
                .symbol == "Morning coffee"
        )
        #expect(
            try QuickExpensePreset(slot: .coffee, symbol: "☕", amount: 35_000).symbol == "☕"
        )
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
                QuickExpenseConfiguration(visibleCount: 3, presets: [coffee])
            )
        }
    }

    @Test("The intent dependency forwards the selected preset slot")
    func intentDependencyForwardsSlot() async throws {
        let recorder = SlotRecorder()
        let feedbackRecorder = SlotRecorder()
        let dependency = QuickExpenseIntentDependency(
            feedbackRecorder: { slot in
                await feedbackRecorder.record(slot)
            }
        ) { slot in
            await recorder.record(slot)
        }

        try await dependency.record(.lunch)

        #expect(await recorder.slots == [.lunch])
        #expect(await feedbackRecorder.slots == [.lunch])
    }

    @Test("Widget success feedback expires after its display duration")
    func widgetSuccessFeedbackExpires() throws {
        let fixture = try makeFeedbackFixture()
        let savedAt = Date(timeIntervalSince1970: 1_000)

        fixture.store.recordSuccess(for: .coffee, at: savedAt)

        #expect(fixture.store.latestSuccess(at: savedAt)?.slot == .coffee)
        #expect(
            fixture.store.latestSuccess(
                at: savedAt.addingTimeInterval(QuickExpenseFeedback.displayDuration - 0.1)
            )?.slot == .coffee
        )
        #expect(
            fixture.store.latestSuccess(
                at: savedAt.addingTimeInterval(QuickExpenseFeedback.displayDuration)
            ) == nil
        )
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

    @Test("An editor draft round trips its configured category")
    func editorDraftRoundTripsCategory() throws {
        let categoryID = UUID()
        let preset = try QuickExpensePreset(
            slot: .coffee,
            symbol: "☕",
            amount: 35_000,
            categoryID: categoryID
        )
        let draft = QuickExpensePresetDraft(preset: preset)

        #expect(draft.categoryID == categoryID)
        #expect(try draft.makePreset().categoryID == categoryID)
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

    private func makeFeedbackFixture() throws -> FeedbackFixture {
        let suiteName = "QuickExpenseFeedbackStoreTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return FeedbackFixture(
            defaults: defaults,
            store: QuickExpenseFeedbackStore(defaults: defaults)
        )
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

    private struct FeedbackFixture {
        let defaults: UserDefaults
        let store: QuickExpenseFeedbackStore
    }

    private struct LegacyPreset: Codable {
        let slot: QuickExpenseSlot
        let symbol: String
        let amount: Decimal
    }

    private actor SlotRecorder {
        private(set) var slots: [QuickExpenseSlot] = []

        func record(_ slot: QuickExpenseSlot) {
            slots.append(slot)
        }
    }
}
