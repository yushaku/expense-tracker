import LocalAuthentication
import Observation
import SwiftUI

/// Guards the app behind Face ID, Touch ID, or the device passcode.
///
/// This is a gate on the screen, not encryption: the SwiftData store on disk is
/// protected by the operating system's file protection and nothing more. It
/// keeps someone who picks up an unlocked device out of the owner's balances;
/// it does not defend the file itself.
@MainActor
@Observable
final class AppLock {
    static let enabledKey = "biometricLockEnabled"

    /// How long the app may sit in the background before it locks again.
    /// Switching away for a moment to copy an amount should not cost a scan.
    static let graceInterval: TimeInterval = 60

    private(set) var isLocked: Bool
    private(set) var failureMessage: String?
    /// True when the device offers neither biometrics nor a passcode, so there
    /// is nothing to authenticate against and locking would only shut the owner
    /// out of their own records.
    private(set) var isUnavailable = false

    private var leftForegroundAt: Date?
    private let defaults: UserDefaults

    var isEnabled: Bool {
        defaults.bool(forKey: Self.enabledKey)
    }

    /// - Parameter defaults: injected so a test never writes to the owner's own
    ///   settings, which live in the host app's domain.
    init(defaults: UserDefaults = .standard, isLocked: Bool? = nil) {
        self.defaults = defaults
        self.isLocked = isLocked ?? defaults.bool(forKey: Self.enabledKey)
    }

    /// The strongest policy this device can actually satisfy. Biometrics are
    /// preferred; the passcode is the fallback so a failed or unenrolled sensor
    /// never becomes a lockout.
    private func availablePolicy(in context: LAContext) -> LAPolicy? {
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            return .deviceOwnerAuthenticationWithBiometrics
        }

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
            return .deviceOwnerAuthentication
        }

        return nil
    }

    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)

        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "your passcode"
        }
    }

    func lockIfEnabled() {
        guard isEnabled else {
            return
        }

        isLocked = true
    }

    /// Called when the app leaves the foreground, so the grace period is
    /// measured from when the owner actually walked away.
    func noteLeftForeground(at date: Date = .now) {
        leftForegroundAt = date
    }

    /// Called when the app comes back. Re-locks only once the grace period has
    /// passed.
    func noteEnteredForeground(at date: Date = .now) {
        guard isEnabled, let leftForegroundAt else {
            return
        }

        if date.timeIntervalSince(leftForegroundAt) >= Self.graceInterval {
            isLocked = true
        }

        self.leftForegroundAt = nil
    }

    func setEnabled(_ isEnabled: Bool) async {
        // Turning the lock on is itself authenticated, so a sensor that does not
        // work is discovered now rather than at the next launch.
        if isEnabled {
            let didAuthenticate = await authenticate(
                reason: "Turn on the lock for MonMon."
            )
            guard didAuthenticate else {
                return
            }
        }

        defaults.set(isEnabled, forKey: Self.enabledKey)

        if !isEnabled {
            isLocked = false
        }
    }

    @discardableResult
    func authenticate(reason: String = "Unlock MonMon.") async -> Bool {
        failureMessage = nil

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        guard let policy = availablePolicy(in: context) else {
            isUnavailable = true
            failureMessage =
                """
                This device has no Face ID, Touch ID, or passcode set, so there is nothing to \
                unlock with.
                """
            return false
        }

        isUnavailable = false

        do {
            let didAuthenticate = try await context.evaluatePolicy(policy, localizedReason: reason)

            if didAuthenticate {
                isLocked = false
            }

            return didAuthenticate
        } catch {
            failureMessage = Self.message(for: error)
            return false
        }
    }

    #if DEBUG
        /// Stands in for a successful scan, which a test cannot perform.
        func setLockedForTesting(_ isLocked: Bool) {
            self.isLocked = isLocked
        }
    #endif

    private static func message(for error: Error) -> String {
        guard let error = error as? LAError else {
            return "Couldn’t unlock. Try again."
        }

        switch error.code {
        case .userCancel, .appCancel, .systemCancel:
            return "Unlock cancelled."
        case .biometryNotEnrolled:
            return "No face or fingerprint is enrolled on this device."
        case .biometryLockout:
            return "Too many attempts. Use the device passcode to unlock."
        case .authenticationFailed:
            return "Not recognised. Try again."
        default:
            return "Couldn’t unlock. Try again."
        }
    }
}
