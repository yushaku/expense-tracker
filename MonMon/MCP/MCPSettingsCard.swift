#if os(macOS)
    import SwiftUI

    struct MCPSettingsCard: View {
        @Environment(MCPAccessManager.self) private var accessManager
        @State private var isReplacementConfirmationPresented = false

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Label("AI access", systemImage: "network.badge.shield.half.filled")
                    .font(.headline)
                    .foregroundStyle(MonMonTheme.textPrimary)

                Toggle(isOn: accessBinding) {
                    Text("Allow AI access")
                        .font(.subheadline.weight(.medium))
                }
                .toggleStyle(.switch)
                .tint(MonMonTheme.accent)
                .disabled(accessManager.isWorking)
                .accessibilityIdentifier("mcp-access-toggle")

                Label(
                    "App Lock does not protect MCP access. An AI client may send your detailed financial records to its model provider.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.danger)
                .accessibilityIdentifier("mcp-privacy-warning")

                Label(
                    "MCP reads a local snapshot. Open MonMon on this Mac to refresh data changed on another device.",
                    systemImage: "externaldrive.fill.badge.timemachine"
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
                .accessibilityIdentifier("mcp-snapshot-note")

                Divider()
                    .overlay(MonMonTheme.border)

                clientRow(
                    name: "Codex", state: accessManager.codexState,
                    accessibilityIdentifier: "mcp-codex-state"
                )
                clientRow(
                    name: "Claude Desktop", state: accessManager.claudeState,
                    accessibilityIdentifier: "mcp-claude-state"
                )

                if accessManager.codexState == .repairNeeded
                    || accessManager.claudeState == .repairNeeded
                {
                    Button {
                        Task { await accessManager.repair() }
                    } label: {
                        Label("Repair client setup", systemImage: "wrench.and.screwdriver.fill")
                    }
                    .buttonStyle(.prominentAction)
                    .disabled(accessManager.isWorking)
                    .accessibilityIdentifier("mcp-repair")
                }

                if accessManager.isWorking {
                    ProgressView("Updating AI client setup…")
                        .controlSize(.small)
                        .accessibilityIdentifier("mcp-working")
                }

                if let message = accessManager.message {
                    Label {
                        Text(LocalizedStringKey(message.text))
                    } icon: {
                        Image(
                            systemName: message.kind == .failure
                                ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(
                        message.kind == .failure ? MonMonTheme.danger : MonMonTheme.textSecondary
                    )
                    .accessibilityIdentifier("mcp-message")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                    .fill(MonMonTheme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
            .task { await accessManager.refresh() }
            .onChange(of: accessManager.needsReplacementConfirmation) { _, needsConfirmation in
                isReplacementConfirmationPresented = needsConfirmation
            }
            .confirmationDialog(
                "Replace the existing server entry?",
                isPresented: $isReplacementConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Replace configuration", role: .destructive) {
                    Task { await accessManager.confirmReplacement() }
                }
                Button("Cancel", role: .cancel) {
                    accessManager.cancelReplacement()
                }
            } message: {
                Text(
                    "A client already has a server with this name or an old MonMon helper path. Only that MonMon entry will be replaced."
                )
            }
        }

        private var accessBinding: Binding<Bool> {
            Binding(
                get: { accessManager.isAllowed },
                set: { newValue in
                    Task { await accessManager.setAllowed(newValue) }
                }
            )
        }

        private func clientRow(
            name: LocalizedStringKey,
            state: MCPClientState,
            accessibilityIdentifier: String
        ) -> some View {
            HStack(spacing: 10) {
                Image(systemName: state.systemImage)
                    .foregroundStyle(state.tint)
                    .accessibilityHidden(true)

                Text(name)
                    .font(.subheadline.weight(.medium))

                Spacer(minLength: 8)

                Text(LocalizedStringKey(state.localizationKey))
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    extension MCPClientState {
        var localizationKey: String {
            switch self {
            case .unavailable: "Not installed"
            case .notConfigured: "Not configured"
            case .current: "Connected after restart"
            case .repairNeeded: "Repair needed"
            case .conflict: "Needs confirmation"
            }
        }

        var systemImage: String {
            switch self {
            case .unavailable: "minus.circle"
            case .notConfigured: "circle.dashed"
            case .current: "checkmark.circle.fill"
            case .repairNeeded: "wrench.and.screwdriver.fill"
            case .conflict: "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .current: MonMonTheme.accent
            case .conflict: MonMonTheme.danger
            default: MonMonTheme.textSecondary
            }
        }
    }
#endif
