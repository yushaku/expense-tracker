#if os(macOS)
    import Foundation
    import Testing

    @testable import MonMon

    @Suite("MCP access manager")
    @MainActor
    struct MCPAccessManagerTests {
        @Test("Enabling exports the snapshot before configuring clients and granting consent")
        func snapshotFirst() async {
            let events = EventLog()
            let consent = FixtureConsent(events: events)
            let installer = FixtureInstaller(events: events)
            let snapshot = FixtureSnapshot(events: events)
            let manager = MCPAccessManager(
                consent: consent, installer: installer, snapshot: snapshot)

            await manager.setAllowed(true)

            #expect(manager.isAllowed)
            #expect(
                events.values == ["snapshot.refresh", "installCodex", "installClaude", "allow"])
        }

        @Test("Disabling revokes consent before client cleanup and remains revoked on failure")
        func revokeFirst() async {
            let events = EventLog()
            let consent = FixtureConsent(events: events, allowed: true)
            let installer = FixtureInstaller(events: events)
            let snapshot = FixtureSnapshot(events: events)
            installer.codex = .current
            installer.removeCodexError = .commandFailed
            let manager = MCPAccessManager(
                consent: consent, installer: installer, snapshot: snapshot)

            await manager.setAllowed(false)

            #expect(events.values.first == "revoke")
            #expect(events.values.dropFirst().first == "snapshot.clear")
            #expect(!consent.isAllowed)
            #expect(!manager.isAllowed)
            #expect(manager.message?.kind == .failure)
        }

        @Test("Disabling never removes a conflicting same-name client entry")
        func preserveConflictsOnDisable() async {
            let events = EventLog()
            let consent = FixtureConsent(events: events, allowed: true)
            let installer = FixtureInstaller(events: events)
            let snapshot = FixtureSnapshot(events: events)
            installer.codex = .conflict
            installer.claude = .conflict
            let manager = MCPAccessManager(
                consent: consent, installer: installer, snapshot: snapshot)

            await manager.setAllowed(false)

            #expect(events.values == ["revoke", "snapshot.clear"])
            #expect(installer.codex == .conflict)
            #expect(installer.claude == .conflict)
        }

        @Test("Conflict pauses enablement until explicit replacement confirmation")
        func conflictConfirmation() async {
            let events = EventLog()
            let consent = FixtureConsent(events: events)
            let installer = FixtureInstaller(events: events)
            let snapshot = FixtureSnapshot(events: events)
            installer.codex = .conflict
            let manager = MCPAccessManager(
                consent: consent, installer: installer, snapshot: snapshot)

            await manager.setAllowed(true)
            #expect(manager.needsReplacementConfirmation)
            #expect(!consent.isAllowed)

            await manager.confirmReplacement()
            #expect(consent.isAllowed)
            #expect(installer.codexReplaced)
            #expect(!manager.needsReplacementConfirmation)
        }

        @Test("Refresh represents unavailable, installed, repair, and error states")
        func refreshStates() async {
            let events = EventLog()
            let consent = FixtureConsent(events: events)
            let installer = FixtureInstaller(events: events)
            let snapshot = FixtureSnapshot(events: events)
            installer.codex = .unavailable
            installer.claude = .repairNeeded
            let manager = MCPAccessManager(
                consent: consent, installer: installer, snapshot: snapshot)

            await manager.refresh()

            #expect(manager.codexState == .unavailable)
            #expect(manager.claudeState == .repairNeeded)
        }

        @Test("A failed snapshot export never grants access or changes client configuration")
        func snapshotFailure() async {
            let events = EventLog()
            let consent = FixtureConsent(events: events)
            let installer = FixtureInstaller(events: events)
            let snapshot = FixtureSnapshot(events: events)
            snapshot.refreshError = .storeUnavailable
            let manager = MCPAccessManager(
                consent: consent, installer: installer, snapshot: snapshot)

            await manager.setAllowed(true)

            #expect(!manager.isAllowed)
            #expect(manager.message?.kind == .failure)
            #expect(events.values == ["snapshot.refresh", "revoke"])
        }

        @Test("Every client state has a localized, user-facing status")
        func clientStatePresentation() {
            let expected: [(MCPClientState, String)] = [
                (.unavailable, "Not installed"),
                (.notConfigured, "Not configured"),
                (.current, "Connected after restart"),
                (.repairNeeded, "Repair needed"),
                (.conflict, "Needs confirmation"),
            ]

            for (state, key) in expected {
                #expect(state.localizationKey == key)
                #expect(AppText.string(key: key, in: Locale(identifier: "vi")) != key)
                #expect(!state.systemImage.isEmpty)
            }
        }
    }

    @MainActor
    private final class EventLog {
        var values: [String] = []
    }

    private final class FixtureConsent: MCPConsentManaging, @unchecked Sendable {
        private let events: EventLog
        var isAllowed: Bool

        init(events: EventLog, allowed: Bool = false) {
            self.events = events
            isAllowed = allowed
        }

        @MainActor func allow() {
            events.values.append("allow")
            isAllowed = true
        }

        @MainActor func revoke() {
            events.values.append("revoke")
            isAllowed = false
        }
    }

    @MainActor
    private final class FixtureSnapshot: MCPSnapshotExporting {
        let events: EventLog
        var refreshError: MCPToolError?

        init(events: EventLog) {
            self.events = events
        }

        func refresh() throws {
            events.values.append("snapshot.refresh")
            if let refreshError { throw refreshError }
        }

        func clear() throws {
            events.values.append("snapshot.clear")
        }
    }

    @MainActor
    private final class FixtureInstaller: MCPClientInstalling {
        let events: EventLog
        var codex: MCPClientState = .notConfigured
        var claude: MCPClientState = .notConfigured
        var removeCodexError: MCPInstallerError?
        var codexReplaced = false

        init(events: EventLog) {
            self.events = events
        }

        func codexState() async -> MCPClientState { codex }
        func claudeState() throws -> MCPClientState { claude }

        func installCodex(replaceExisting: Bool) async throws {
            events.values.append("installCodex")
            codexReplaced = replaceExisting
            codex = .current
        }

        func installClaude(replaceExisting: Bool) throws {
            events.values.append("installClaude")
            claude = .current
        }

        func removeCodex() async throws {
            events.values.append("removeCodex")
            if let removeCodexError { throw removeCodexError }
            codex = .notConfigured
        }

        func removeClaude() throws {
            events.values.append("removeClaude")
            claude = .notConfigured
        }
    }
#endif
