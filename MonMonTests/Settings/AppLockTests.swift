import Foundation
import Testing

@testable import MonMon

@Suite("App lock")
@MainActor
struct AppLockTests {
    private let leftAt = Date(timeIntervalSince1970: 1_787_000_000)

    /// A throwaway domain, so a test never writes to the owner's own settings.
    private func makeLock(isEnabled: Bool) -> AppLock {
        let suiteName = "monmon.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(isEnabled, forKey: AppLock.enabledKey)
        return AppLock(defaults: defaults)
    }

    @Test("A new lock starts locked only when the setting is on")
    func startsLockedWhenEnabled() {
        #expect(makeLock(isEnabled: true).isLocked)
        #expect(!makeLock(isEnabled: false).isLocked)
    }

    @Test("Coming back within the grace period leaves an unlocked app open")
    func graceKeepsAnUnlockedAppOpen() {
        let lock = makeLock(isEnabled: true)
        lock.setLockedForTesting(false)

        lock.noteLeftForeground(at: leftAt)
        lock.noteEnteredForeground(at: leftAt.addingTimeInterval(AppLock.graceInterval - 1))

        #expect(!lock.isLocked)
    }

    @Test("Coming back after the grace period locks again")
    func longAbsenceRelocks() {
        let lock = makeLock(isEnabled: true)
        lock.setLockedForTesting(false)

        lock.noteLeftForeground(at: leftAt)
        lock.noteEnteredForeground(at: leftAt.addingTimeInterval(AppLock.graceInterval))

        #expect(lock.isLocked)
    }

    @Test("With the setting off, time away changes nothing")
    func disabledLockNeverRelocks() {
        let lock = makeLock(isEnabled: false)

        lock.noteLeftForeground(at: leftAt)
        lock.noteEnteredForeground(at: leftAt.addingTimeInterval(AppLock.graceInterval * 10))
        lock.lockIfEnabled()

        #expect(!lock.isLocked)
    }

    @Test("Returning without having left does not lock")
    func returningWithoutLeavingDoesNothing() {
        let lock = makeLock(isEnabled: true)
        lock.setLockedForTesting(false)

        lock.noteEnteredForeground(at: leftAt)

        #expect(!lock.isLocked)
    }

    @Test("Leaving twice measures from the most recent departure")
    func theLatestDepartureWins() {
        let lock = makeLock(isEnabled: true)
        lock.setLockedForTesting(false)

        lock.noteLeftForeground(at: leftAt)
        lock.noteLeftForeground(at: leftAt.addingTimeInterval(AppLock.graceInterval * 2))
        lock.noteEnteredForeground(
            at: leftAt.addingTimeInterval(AppLock.graceInterval * 2 + 1)
        )

        #expect(!lock.isLocked)
    }
}
