#if os(macOS)
    import Foundation
    import Observation
    import SwiftData

    @MainActor
    @Observable
    final class MCPAccessManager {
        enum MessageKind: Equatable {
            case information
            case failure
        }

        struct Message: Equatable {
            let kind: MessageKind
            let text: String
        }

        private(set) var isAllowed: Bool
        private(set) var isWorking = false
        private(set) var codexState: MCPClientState = .notConfigured
        private(set) var claudeState: MCPClientState = .notConfigured
        private(set) var message: Message?
        private(set) var needsReplacementConfirmation = false

        private let consent: any MCPConsentManaging
        private let installer: any MCPClientInstalling
        private let registration: any MCPStoreRegistering

        init(
            consent: any MCPConsentManaging,
            installer: any MCPClientInstalling,
            registration: any MCPStoreRegistering
        ) {
            self.consent = consent
            self.installer = installer
            self.registration = registration
            isAllowed = consent.isAllowed
        }

        convenience init(
            configuration: MCPRuntimeConfiguration,
            sourceContext: ModelContext,
            bundle: Bundle = .main
        ) throws {
            let consent = try MCPConsentStore(configuration: configuration)
            let helperURL = bundle.bundleURL.appending(path: "Contents/Helpers/MonMonMCPServer")
            guard let defaults = UserDefaults(suiteName: configuration.appGroupIdentifier) else {
                throw MCPToolError.storeUnavailable
            }
            let registration = MCPStoreRegistration(
                container: sourceContext.container, defaults: defaults,
                legacyURL: ModelConfiguration(
                    "MonMonMCPSnapshot",
                    groupContainer: .identifier(configuration.appGroupIdentifier),
                    cloudKitDatabase: .none
                ).url)
            self.init(
                consent: consent,
                installer: MCPClientInstaller(
                    serverName: configuration.serverName, helperURL: helperURL),
                registration: registration)
            if !MonMonProcess.isRunningUnitTests {
                do {
                    if consent.isAllowed {
                        try registration.register()
                    } else {
                        try registration.clear()
                    }
                } catch {
                    try? registration.clear()
                    message = Message(
                        kind: .failure,
                        text: "The local store could not be registered for AI access.")
                }
            }
        }

        func refresh() async {
            codexState = await installer.codexState()
            do {
                claudeState = try installer.claudeState()
            } catch {
                claudeState = .conflict
                message = Message(
                    kind: .failure,
                    text: "Claude Desktop's configuration could not be read safely."
                )
            }
            isAllowed = consent.isAllowed
        }

        func setAllowed(_ newValue: Bool) async {
            guard newValue != isAllowed else { return }
            message = nil
            if newValue {
                await beginEnablement()
            } else {
                await disable()
            }
        }

        func confirmReplacement() async {
            guard needsReplacementConfirmation else { return }
            await enable(replaceExisting: true)
        }

        func cancelReplacement() {
            needsReplacementConfirmation = false
            message = Message(
                kind: .information,
                text: "No client configuration was changed."
            )
        }

        func repair() async {
            message = nil
            isWorking = true
            defer { isWorking = false }
            do {
                if codexState == .repairNeeded {
                    try await installer.installCodex(replaceExisting: true)
                }
                if claudeState == .repairNeeded {
                    try installer.installClaude(replaceExisting: true)
                }
                await refresh()
                message = Message(
                    kind: .information,
                    text: "Client configuration repaired. Restart the AI client to reconnect."
                )
            } catch {
                message = Message(
                    kind: .failure, text: "Client configuration could not be repaired.")
            }
        }

        private func beginEnablement() async {
            isWorking = true
            await refresh()
            isWorking = false
            if [codexState, claudeState].contains(where: { $0 == .conflict || $0 == .repairNeeded })
            {
                needsReplacementConfirmation = true
                return
            }
            await enable(replaceExisting: false)
        }

        private func enable(replaceExisting: Bool) async {
            isWorking = true
            defer { isWorking = false }
            do {
                try registration.register()
                if codexState != .unavailable {
                    try await installer.installCodex(replaceExisting: replaceExisting)
                }
                if claudeState != .unavailable {
                    try installer.installClaude(replaceExisting: replaceExisting)
                }
                consent.allow()
                isAllowed = true
                needsReplacementConfirmation = false
                await refresh()
                message = Message(
                    kind: .information,
                    text: "AI access is enabled. Restart Codex or Claude Desktop to connect."
                )
            } catch {
                consent.revoke()
                isAllowed = false
                message = Message(
                    kind: .failure, text: "AI access could not be enabled.")
            }
        }

        private func disable() async {
            isWorking = true
            consent.revoke()
            isAllowed = false
            needsReplacementConfirmation = false
            var cleanupFailed = false
            do { try registration.clear() } catch { cleanupFailed = true }

            await refresh()
            if codexState == .current || codexState == .repairNeeded {
                do { try await installer.removeCodex() } catch { cleanupFailed = true }
            }
            if claudeState == .current || claudeState == .repairNeeded {
                do { try installer.removeClaude() } catch { cleanupFailed = true }
            }
            await refresh()
            isWorking = false
            message =
                cleanupFailed
                ? Message(
                    kind: .failure,
                    text:
                        "AI access is off, but local cleanup was incomplete. The helper will still refuse data."
                )
                : Message(
                    kind: .information,
                    text:
                        "AI access is off. Restart the AI client to remove the disconnected server."
                )
        }
    }

#endif
