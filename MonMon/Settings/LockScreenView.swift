import SwiftUI

/// Covers the app while it is locked. Nothing behind it is readable, so a
/// glance at the screen shows no balances.
struct LockScreenView: View {
    let biometryName: String
    let failureMessage: String?
    let isUnavailable: Bool
    let onUnlock: () -> Void
    let onTurnOffLock: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(MonMonTheme.accent)
                    .frame(width: 76, height: 76)
                    .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("MonMon is locked")
                        .font(.title3.weight(.semibold))

                    Text("Unlock with \(biometryName) to see your balances.")
                        .font(.subheadline)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }

                if let failureMessage {
                    Label(failureMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.danger)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                        .accessibilityIdentifier("unlock-error")
                }

                Button("Unlock", systemImage: "faceid", action: onUnlock)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("unlock")

                // Without a sensor or a passcode there is nothing to
                // authenticate against, so the only honest way out is to say so
                // and let the owner switch the lock off.
                if isUnavailable {
                    Button("Turn off the lock", action: onTurnOffLock)
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MonMonTheme.danger)
                        .accessibilityIdentifier("turn-off-lock")
                }
            }
            .padding(32)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
}

#if DEBUG
    #Preview("Locked") {
        LockScreenView(
            biometryName: "Face ID",
            failureMessage: nil,
            isUnavailable: false,
            onUnlock: {},
            onTurnOffLock: {}
        )
    }

    #Preview("Locked · failed") {
        LockScreenView(
            biometryName: "Touch ID",
            failureMessage: "Not recognised. Try again.",
            isUnavailable: false,
            onUnlock: {},
            onTurnOffLock: {}
        )
    }
#endif
