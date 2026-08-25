import CloudKit
import CoreData
import Observation
import SwiftData
import SwiftUI

/// The owner's switch for iCloud mirroring, and the little a client can honestly
/// report about it.
///
/// ## Why the switch waits for the next launch
///
/// SwiftData decides whether a store mirrors to CloudKit when the container is
/// built, and there is no way to rebuild that container under a running app
/// without closing the store every open screen is reading from. So the switch
/// writes a preference and the next launch acts on it. Saying so on screen is
/// better than swapping the store underneath a half-typed transaction.
///
/// ## Why "Sync now" cannot promise a push
///
/// Mirroring is the system's to schedule; no public call forces it. What the
/// button can do is flush unsaved edits, confirm the iCloud account is usable,
/// and then report the next mirroring event the store publishes. That is the
/// same evidence the app has at any other moment — asked for on purpose, and
/// reported without claiming more than it saw.
@MainActor
@Observable
final class CloudSync {
    static let enabledKey = "iCloudSyncEnabled"
    static let lastSyncedAtKey = "iCloudLastSyncedAt"
    /// The CloudKit container this build mirrors to. Set per configuration in
    /// the xcconfigs and read back from the bundle, so the dev and prod flavours
    /// can never reach each other's records. A build that lost the key is
    /// misconfigured in a way no fallback could make safe: guessing would point
    /// a dev build at the owner's real data.
    static let containerIdentifier: String = {
        guard
            let identifier = Bundle.main.object(
                forInfoDictionaryKey: "MonMonCloudKitContainer"
            ) as? String,
            !identifier.isEmpty
        else {
            fatalError("MonMonCloudKitContainer missing from Info.plist")
        }
        return identifier
    }()

    /// How long the button waits for the store to publish an event before it
    /// stops speaking for the result. Mirroring carries on either way, so the
    /// wait is about what the app may claim, not about what it does.
    static let eventTimeout: TimeInterval = 10

    /// A line to put under the button: what happened, and whether it went wrong.
    struct Message: Equatable {
        var text: String
        var isFailure: Bool
    }

    /// One mirroring event, reduced to what this class acts on. Keeping the
    /// Core Data type at the edge is what lets a test drive the same path.
    struct Event: Equatable {
        var endedAt: Date
        var errorDescription: String?

        var didSucceed: Bool { errorDescription == nil }
    }

    private(set) var isEnabled: Bool
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?
    private(set) var message: Message?

    /// True once the switch no longer matches the store this launch opened.
    var needsRelaunch: Bool { isEnabled != enabledAtLaunch }

    private let defaults: UserDefaults
    private let accountStatus: () async -> CKAccountStatus
    private let enabledAtLaunch: Bool
    /// Not owner-visible state, and touched only on the main thread; the
    /// annotation is what lets `deinit` hand it back.
    @ObservationIgnored nonisolated(unsafe) private var observer: (any NSObjectProtocol)?

    /// Synchronisation is on unless the owner turned it off, because every store
    /// written before this switch existed was already mirroring.
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    /// - Parameters:
    ///   - defaults: injected so a test never writes to the owner's own
    ///     settings, which live in the host app's domain.
    ///   - accountStatus: injected so a test can stand in for an account the
    ///     simulator does not have.
    init(
        defaults: UserDefaults = .standard,
        accountStatus: (() async -> CKAccountStatus)? = nil
    ) {
        self.defaults = defaults
        self.accountStatus =
            accountStatus
            ?? {
                let container = CKContainer(identifier: CloudSync.containerIdentifier)
                return (try? await container.accountStatus()) ?? .couldNotDetermine
            }
        let isEnabled = Self.isEnabled(in: defaults)
        self.isEnabled = isEnabled
        enabledAtLaunch = isEnabled
        lastSyncedAt = defaults.object(forKey: Self.lastSyncedAtKey) as? Date
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Starts listening for mirroring events, so "Last synced" is true even when
    /// the owner never pressed the button.
    func startObserving(center: NotificationCenter = .default) {
        guard observer == nil else {
            return
        }

        observer = center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let event = notification.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event,
                // An event without an end date is one still running; it says
                // nothing about the outcome yet.
                let endedAt = event.endDate
            else {
                return
            }

            // Only the two plain values cross into the actor; the Core Data
            // event itself stays on the queue that delivered it.
            let errorDescription = event.error?.localizedDescription

            MainActor.assumeIsolated {
                self?.note(Event(endedAt: endedAt, errorDescription: errorDescription))
            }
        }
    }

    /// Records what a mirroring event reported. A failure is kept on screen; a
    /// success moves the timestamp the owner reads.
    func note(_ event: Event) {
        guard event.didSucceed else {
            message = Message(
                text: "iCloud reported a problem: \(event.errorDescription ?? "unknown").",
                isFailure: true
            )
            return
        }

        lastSyncedAt = event.endedAt
        defaults.set(event.endedAt, forKey: Self.lastSyncedAtKey)
    }

    func setEnabled(_ newValue: Bool) {
        guard newValue != isEnabled else {
            return
        }

        isEnabled = newValue
        defaults.set(newValue, forKey: Self.enabledKey)
        message = nil
    }

    /// Saves what is pending, checks the account, and reports the next event the
    /// store publishes — or says plainly that none arrived in time.
    func syncNow(context: ModelContext, now: () -> Date = Date.init) async {
        guard isEnabled, !isSyncing else {
            return
        }

        isSyncing = true
        message = nil
        defer { isSyncing = false }

        do {
            try context.save()
        } catch {
            message = Message(
                text: "Couldn't save the pending changes: \(error.localizedDescription)",
                isFailure: true
            )
            return
        }

        let status = await accountStatus()
        guard status == .available else {
            message = Message(text: Self.text(for: status), isFailure: true)
            return
        }

        message = await waitForEvent(since: lastSyncedAt, now: now)
    }

    /// Polls rather than awaiting a single event, because the event that answers
    /// the press may be one that was already in flight when it happened.
    private func waitForEvent(since previous: Date?, now: () -> Date) async -> Message {
        let deadline = now().addingTimeInterval(Self.eventTimeout)

        while now() < deadline {
            if let message, message.isFailure {
                return message
            }

            if lastSyncedAt != previous {
                return Message(text: "iCloud is up to date.", isFailure: false)
            }

            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                break
            }
        }

        return Message(
            text: """
                iCloud hasn't reported back yet. Anything unsent stays queued and uploads on its \
                own.
                """,
            isFailure: false
        )
    }

    private static func text(for status: CKAccountStatus) -> String {
        switch status {
        case .noAccount:
            return "No iCloud account is signed in on this device."
        case .restricted:
            return "iCloud is restricted on this device, so MonMon can't reach it."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. Try again in a moment."
        default:
            return "Couldn't reach iCloud. Check the connection and try again."
        }
    }
}
