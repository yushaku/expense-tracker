import CoreImage.CIFilterBuiltins
import SwiftUI

struct SyncView: View {
    @Environment(SyncCoordinator.self) private var sync
    @Environment(AppLock.self) private var appLock
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var showScanner = false
    @State private var confirmUnpair = false

    var body: some View {
        @Bindable var sync = sync
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label(
                        "Sync directly between your devices",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.title3.bold())
                    Text(
                        "Open MonMon on both devices on the same Wi-Fi. Review changes before applying them to both devices."
                    )
                    .foregroundStyle(.secondary)
                    status
                    if let error = sync.errorMessage {
                        Text(error).foregroundStyle(.red).accessibilityIdentifier("sync-error")
                    }
                    if !sync.isPaired {
                        pairing
                    } else {
                        if let pairingCode = sync.pairingCode { qr(pairingCode) }
                        if sync.plan != nil {
                            review
                        } else {
                            HStack {
                                if sync.canStart {
                                    Button("Sync", systemImage: "arrow.triangle.2.circlepath") {
                                        sync.startSync()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("sync-start")
                                } else if sync.phase == .idle || sync.phase == .interrupted {
                                    Button("Connect", systemImage: "wifi") { sync.connect() }
                                        .buttonStyle(.borderedProminent)
                                }
                                if !sync.hasPending {
                                    Button("Unpair", role: .destructive) { confirmUnpair = true }
                                }
                            }
                        }
                    }
                    if sync.hasPending {
                        Text(
                            "A sync is unfinished. Reconnect the paired device to finish it. Data already saved will not be applied twice."
                        )
                        .font(.callout).foregroundStyle(.secondary)
                    }
                    history
                    Text(
                        "Drafts and device settings stay on this device. Devices on guest Wi-Fi may be unable to discover each other. Allow Local Network access in system settings if discovery is blocked."
                    )
                    .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(MonMonTheme.canvas)
            .navigationTitle("Device Sync")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        sync.disconnect()
                        dismiss()
                    }
                    .disabled(sync.writesLocked)
                }
            }
            .interactiveDismissDisabled(sync.writesLocked)
            .onChange(of: sync.choices) { _, _ in sync.updatePreview() }
            .onChange(of: appLock.isLocked) { _, locked in if locked { sync.disconnect() } }
            .onChange(of: scenePhase) { _, phase in if phase == .background { sync.disconnect() } }
            .onDisappear { sync.disconnect() }
            .confirmationDialog(
                "Unpair this device?", isPresented: $confirmUnpair, titleVisibility: .visible
            ) {
                Button("Unpair", role: .destructive) { sync.unpair() }
            } message: {
                Text("Your local data stays intact. Pair again to sync with another device.")
            }
            #if os(iOS)
                .sheet(isPresented: $showScanner) {
                    SyncQRScanner { result in
                        showScanner = false
                        if let result { sync.acceptPairing(result) }
                    }
                }
            #endif
        }
        .frame(minWidth: 320, idealWidth: 680, minHeight: 420, idealHeight: 700)
        .privacySensitive()
        .accessibilityHidden(appLock.isLocked)
        .overlay {
            if appLock.isLocked {
                MonMonTheme.canvas.overlay {
                    Button("Unlock MonMon") { Task { _ = await appLock.authenticate() } }
                }
            }
        }
    }

    private var status: some View {
        HStack(spacing: 12) {
            if [.waiting, .comparing, .applying].contains(sync.phase) {
                ProgressView()
            } else {
                Image(
                    systemName: sync.phase == .complete
                        ? "checkmark.circle.fill" : "laptopcomputer.and.iphone")
            }
            VStack(alignment: .leading) {
                Text(LocalizedStringKey(sync.phase.rawValue)).font(.headline)
                if !sync.peerName.isEmpty { Text(sync.peerName).foregroundStyle(.secondary) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sync-status")
    }

    private var pairing: some View {
        VStack(alignment: .leading, spacing: 12) {
            #if os(macOS)
                Button("Pair an iPhone", systemImage: "qrcode") { sync.createPairing() }
                    .buttonStyle(.borderedProminent)
            #else
                Button("Scan Mac pairing code", systemImage: "qrcode.viewfinder") {
                    showScanner = true
                }
                .buttonStyle(.borderedProminent)
            #endif
            DisclosureGroup("Enter pairing code manually") {
                SecureField("Pairing code", text: $code)
                    .textFieldStyle(.roundedBorder)
                Button("Pair") {
                    sync.acceptPairing(code)
                    code = ""
                }
                .disabled(code.isEmpty)
            }
        }
    }

    @ViewBuilder
    private func qr(_ value: String) -> some View {
        if let image = Self.qrImage(value) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scan this code in MonMon on your iPhone.")
                Image(decorative: image, scale: 1)
                    .interpolation(.none).resizable().scaledToFit()
                    .frame(width: 260, height: 260)
                    .padding(12).background(.white)
                    .accessibilityLabel("Pairing QR code")
                DisclosureGroup("Show pairing code") {
                    Text(value).font(.caption.monospaced()).textSelection(.enabled)
                }
            }
        }
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let plan = sync.plan {
                ForEach(plan.conflicts) { conflict in
                    conflictCard(conflict)
                }
                if sync.canApply {
                    changes("This device", rows: sync.previewLocal)
                    changes("Other device", rows: sync.previewRemote)
                    Button("Apply to both devices") { sync.apply() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("sync-apply")
                }
                Button("Cancel") { sync.cancelReview() }
                    .disabled(sync.hasPending)
            }
        }
    }

    private func conflictCard(_ conflict: SyncConflict) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose which version to keep").font(.headline)
            Text(conflict.options.compactMap { $0 }.first?.title ?? "Deleted")
                .font(.subheadline.bold())
            ForEach(conflict.optionIDs, id: \.self) { optionID in
                let index = conflict.optionIDs.firstIndex(of: optionID) ?? 0
                let record = conflict.options[index]
                Button {
                    sync.choices[conflict.id] = index
                } label: {
                    HStack(alignment: .top) {
                        Image(
                            systemName: sync.choices[conflict.id] == index
                                ? "checkmark.circle.fill" : "circle")
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey(conflict.origins[index])).font(.headline)
                            if let record {
                                SyncRecordDetails(record: record)
                            } else {
                                Text("Delete / keep absent").foregroundStyle(.red)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(sync.choices[conflict.id] == index ? [.isSelected] : [])
            }
        }
    }

    private func changes(_ title: LocalizedStringKey, rows: [SyncChange]) -> some View {
        DisclosureGroup {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(LocalizedStringKey(row.kind))
                        Text(SyncLabels.type(row.after?.type ?? row.before?.type ?? ""))
                            .foregroundStyle(.secondary)
                    }.font(.caption)
                    Text(row.after?.title ?? row.before?.title ?? "")
                    DisclosureGroup("Details") {
                        if let before = row.before {
                            Text("Before").font(.caption.bold())
                            SyncRecordDetails(record: before)
                        }
                        if let after = row.after {
                            Text("After").font(.caption.bold())
                            SyncRecordDetails(record: after)
                        }
                    }
                    Divider()
                }
            }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(rows.count, format: .number)
            }
        }
    }

    @ViewBuilder
    private var history: some View {
        if !sync.reports.isEmpty {
            Divider()
            Text("Recent syncs").font(.headline)
            ForEach(sync.reports) { report in
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.peerName).font(.subheadline.bold())
                    Text(report.completedAt, format: .dateTime.day().month().hour().minute())
                    Text(
                        "Added: \(report.added) · Updated: \(report.updated) · Deleted: \(report.deleted)"
                    )
                    if let recovery = sync.store.recoveryFile(for: report.id) {
                        ShareLink("Export recovery backup", item: recovery)
                    }
                }.font(.caption)
            }
        }
    }

    private static func qrImage(_ value: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}

private struct SyncRecordDetails: View {
    @Environment(SyncCoordinator.self) private var sync
    let record: SyncRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(record.fields.keys.sorted().filter { $0 != "id" }, id: \.self) { key in
                if let value = record.fields[key], value != .null {
                    Text("\(SyncLabels.field(key)): \(sync.displayValue(value, field: key))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

enum SyncLabels {
    static func type(_ value: String) -> String {
        let names = [
            "accounts": "Accounts", "categories": "Categories", "transactions": "Transactions",
            "transfers": "Transfers", "savingsDeposits": "Savings",
            "savingsWithdrawals": "Withdrawals", "fundInstruments": "Instruments",
            "fundHoldings": "Holdings", "fundSales": "Sales", "budgetJars": "Budget jars",
            "goals": "Goals", "tripWorkspaces": "Trips", "debts": "Debts",
            "debtPayments": "Debt payments", "recurringRules": "Recurring rules",
        ]
        return AppText.string(key: names[value] ?? value, in: AppLanguage.stored.locale)
    }
    static func field(_ key: String) -> String {
        let words = key.replacingOccurrences(
            of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        return AppText.string(
            key: words.prefix(1).uppercased() + words.dropFirst(), in: AppLanguage.stored.locale)
    }
    static func value(_ value: SyncValue) -> String {
        switch value {
        case .string(let text): return text
        case .number(let number): return NSDecimalNumber(decimal: number).stringValue
        case .bool(let bool):
            return AppText.string(key: bool ? "Yes" : "No", in: AppLanguage.stored.locale)
        case .array(let values): return values.map(Self.value).joined(separator: ", ")
        case .object(let values):
            return values.keys.sorted().map { field($0) + ": " + Self.value(values[$0] ?? .null) }
                .joined(separator: "; ")
        case .null: return "—"
        }
    }
}
