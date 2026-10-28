import Foundation
import Observation

/// Owns the one operation that deletes every model the app's views may still
/// be holding: backing up and resetting the local database.
///
/// SwiftUI's retained rows and sheets keep references to the deleted models,
/// so the content tree is replaced (`revision` is its identity) before its next
/// render rather than asked to redraw them.
@MainActor
@Observable
final class StoreResetCoordinator {
    private(set) var revision = 0
    var isPresentingResetNotice = false

    /// Runs after a successful reset, for work outside the store such as
    /// rescheduling notifications.
    @ObservationIgnored var onReset: (() -> Void)?

    func resetDatabase(using service: MonMonBackupService, backupURL: URL) throws {
        try service.reset(backupURL: backupURL)
        revision += 1
        isPresentingResetNotice = true
        onReset?()
    }
}
