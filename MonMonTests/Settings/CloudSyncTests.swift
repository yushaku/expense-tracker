import CloudKit
import Foundation
import SwiftData
import Testing

@testable import MonMon

@Suite("iCloud sync settings")
@MainActor
struct CloudSyncTests {
    private let syncedAt = Date(timeIntervalSince1970: 1_787_000_000)

    /// A throwaway domain, so a test never writes to the owner's own settings.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "monmon.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(MonMonSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container.mainContext
    }

    @Test("A store that was never switched stays off the network")
    func defaultsToOff() {
        let defaults = makeDefaults()

        #expect(!CloudSync.isEnabled(in: defaults))
        #expect(!CloudSync(defaults: defaults).isEnabled)
    }

    @Test("Turning the switch on is remembered for the next launch")
    func turningOnPersists() {
        let defaults = makeDefaults()
        let sync = CloudSync(defaults: defaults)

        sync.setEnabled(true)

        #expect(sync.isEnabled)
        #expect(CloudSync.isEnabled(in: defaults))
    }

    @Test("Moving the switch asks for a relaunch, and moving it back stops asking")
    func relaunchFollowsTheSwitch() {
        let sync = CloudSync(defaults: makeDefaults())
        #expect(!sync.needsRelaunch)

        sync.setEnabled(true)
        #expect(sync.needsRelaunch)

        sync.setEnabled(false)
        #expect(!sync.needsRelaunch)
    }

    @Test("A finished mirroring event is the timestamp the owner reads")
    func successfulEventMovesTheTimestamp() {
        let defaults = makeDefaults()
        let sync = CloudSync(defaults: defaults)

        sync.note(CloudSync.Event(endedAt: syncedAt, errorDescription: nil))

        #expect(sync.lastSyncedAt == syncedAt)
        // Written through, so the line survives a relaunch.
        #expect(CloudSync(defaults: defaults).lastSyncedAt == syncedAt)
    }

    @Test("A failed mirroring event is shown and leaves the timestamp alone")
    func failedEventIsSurfaced() {
        let sync = CloudSync(defaults: makeDefaults())

        sync.note(CloudSync.Event(endedAt: syncedAt, errorDescription: "quota exceeded"))

        #expect(sync.lastSyncedAt == nil)
        #expect(sync.message?.isFailure == true)
        #expect(sync.message?.text.contains("quota exceeded") == true)
    }

    @Test("Syncing without an iCloud account says so instead of waiting")
    func missingAccountIsReported() async throws {
        let sync = CloudSync(defaults: makeDefaults(), accountStatus: { .noAccount })
        sync.setEnabled(true)

        await sync.syncNow(context: try makeContext())

        #expect(sync.message?.isFailure == true)
        #expect(sync.message?.text.contains("No iCloud account") == true)
        #expect(!sync.isSyncing)
    }

    @Test("An event that lands during the wait ends it with an up-to-date line")
    func eventDuringTheWaitEndsIt() async throws {
        let sync = CloudSync(defaults: makeDefaults(), accountStatus: { .available })
        sync.setEnabled(true)
        let context = try makeContext()

        let pressed = Task { await sync.syncNow(context: context) }
        // The button is waiting on the store; standing in for the event it is
        // waiting for is the only way a test can supply one.
        try await Task.sleep(for: .milliseconds(300))
        sync.note(CloudSync.Event(endedAt: syncedAt, errorDescription: nil))
        await pressed.value

        #expect(sync.message == CloudSync.Message(text: "iCloud is up to date.", isFailure: false))
        #expect(sync.lastSyncedAt == syncedAt)
    }

    @Test("A silent store ends the wait without claiming a sync happened")
    func silenceEndsTheWait() async throws {
        let sync = CloudSync(defaults: makeDefaults(), accountStatus: { .available })
        sync.setEnabled(true)
        var clock = Date(timeIntervalSince1970: 0)

        // A hand-wound clock, so the timeout is proven without spending it.
        await sync.syncNow(context: try makeContext()) {
            defer { clock.addTimeInterval(CloudSync.eventTimeout) }
            return clock
        }

        #expect(sync.lastSyncedAt == nil)
        #expect(sync.message?.isFailure == false)
        #expect(sync.message?.text.contains("hasn't reported back") == true)
    }

    @Test("The switch being off makes the button a no-op")
    func syncingWhileOffDoesNothing() async throws {
        let sync = CloudSync(defaults: makeDefaults(), accountStatus: { .noAccount })

        await sync.syncNow(context: try makeContext())

        #expect(sync.message == nil)
    }
}
