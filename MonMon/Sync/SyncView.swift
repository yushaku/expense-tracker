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
                    status
                    if let error = sync.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("sync-error")
                    }
                    if !sync.isPaired {
                        pairing
                    } else {
                        if let pairingCode = sync.pairingCode { qr(pairingCode) }
                        if sync.plan != nil {
                            review
                        }
                    }
                    if sync.hasPending {
                        Text(
                            "A sync is unfinished. Reconnect the paired device to finish it. Data already saved will not be applied twice."
                        )
                        .font(.callout).foregroundStyle(.secondary)
                    }
                    history
                    DisclosureGroup("About device sync") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(
                                "Open MonMon on both devices on the same Wi-Fi. Review changes before applying them to both devices."
                            )
                            Text(
                                "Drafts and device settings stay on this device. Devices on guest Wi-Fi may be unable to discover each other. Allow Local Network access in system settings if discovery is blocked."
                            )
                            if sync.isPaired && !sync.hasPending && sync.plan == nil {
                                Button("Unpair", role: .destructive) { confirmUnpair = true }
                            }
                        }
                        .font(.callout).foregroundStyle(.secondary)
                        .padding(.top, 8)
                    }
                }
                .padding(20)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(MonMonTheme.canvas)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Text("Device Sync").font(.headline)
                    Spacer()
                    Button("Close", systemImage: "xmark") {
                        sync.disconnect()
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .frame(width: 44, height: 44)
                    .disabled(sync.writesLocked)
                    .accessibilityIdentifier("sync-close")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
                .background(MonMonTheme.surface)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actions
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
        #if os(macOS)
            .frame(width: 720, height: 740)
        #endif
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
        HStack(spacing: 16) {
            if [.waiting, .comparing, .applying].contains(sync.phase) {
                ProgressView()
            } else {
                Image(
                    systemName: sync.phase == .complete
                        ? "checkmark.circle.fill" : "laptopcomputer.and.iphone"
                )
                .font(.title2)
                .foregroundStyle(MonMonTheme.accent)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(sync.isPaired ? LocalizedStringKey(sync.phase.rawValue) : "Pair your devices")
                    .font(.title3.bold())
                if !sync.peerName.isEmpty { Text(sync.peerName).foregroundStyle(.secondary) }
                if !sync.isPaired {
                    Text("Keep MonMon open on your Mac and iPhone, using the same Wi-Fi.")
                        .font(.callout).foregroundStyle(.secondary)
                } else if sync.phase == .review {
                    Text("Choose the version to keep. Nothing is saved until both devices approve.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sync-status")
    }

    private var pairing: some View {
        VStack(alignment: .leading, spacing: 12) {
            #if os(macOS)
                Button("Pair an iPhone", systemImage: "qrcode") { sync.createPairing() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            #else
                Button("Scan Mac pairing code", systemImage: "qrcode.viewfinder") {
                    showScanner = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
                    .frame(maxWidth: 240)
                    .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: .infinity)
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
                if !plan.conflicts.isEmpty {
                    Text("iPhone versions are selected by default. You can change any selection.")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Text("Choose versions").font(.headline)
                        Spacer()
                        Text(
                            "\(plan.conflicts.count - unresolvedCount) of \(plan.conflicts.count) selected"
                        )
                        .font(.callout).foregroundStyle(.secondary)
                    }
                }
                ForEach(plan.conflicts) { conflict in
                    conflictCard(conflict)
                }
                if sync.canApply {
                    Text("Changes to apply").font(.headline)
                    changes("This device", rows: sync.previewLocal)
                    changes("Other device", rows: sync.previewRemote)
                }
            }
        }
    }

    private var unresolvedCount: Int {
        sync.plan?.conflicts.filter { sync.choices[$0.id] == nil }.count ?? 0
    }

    @ViewBuilder
    private var actions: some View {
        if sync.isPaired {
            VStack(alignment: .leading, spacing: 8) {
                if sync.phase == .review && unresolvedCount > 0 {
                    Text("\(unresolvedCount) choices remaining")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    if sync.plan != nil {
                        Button("Cancel") { sync.cancelReview() }
                            .disabled(sync.hasPending)
                        Spacer(minLength: 0)
                        if sync.phase == .review {
                            Button("Apply to both devices") { sync.apply() }
                                .buttonStyle(.borderedProminent)
                                .disabled(!sync.canApply)
                                .accessibilityIdentifier("sync-apply")
                        }
                    } else if sync.canStart {
                        Spacer(minLength: 0)
                        Button("Review changes", systemImage: "arrow.triangle.2.circlepath") {
                            sync.startSync()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("sync-start")
                    } else if sync.phase == .idle || sync.phase == .interrupted {
                        Spacer(minLength: 0)
                        Button("Connect", systemImage: "wifi") { sync.connect() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Text(LocalizedStringKey(sync.phase.rawValue))
                            .font(.callout).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                }
                .controlSize(.large)
            }
            .padding(16)
            .background(MonMonTheme.surface)
        }
    }

    private func conflictCard(_ conflict: SyncConflict) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SyncLabels.type(conflict.options.compactMap { $0 }.first?.type ?? ""))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(conflict.options.compactMap { $0 }.first?.title ?? "Deleted")
                        .font(.headline)
                }
                Spacer(minLength: 0)
                if sync.choices[conflict.id] != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MonMonTheme.accent)
                        .accessibilityLabel("Selected")
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                ForEach(conflict.optionIDs, id: \.self) { optionID in
                    let index = conflict.optionIDs.firstIndex(of: optionID) ?? 0
                    let record = conflict.options[index]
                    let selected = sync.choices[conflict.id] == index
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            sync.choices[conflict.id] = index
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(
                                        selected ? MonMonTheme.accent : MonMonTheme.textSecondary)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(LocalizedStringKey(conflict.origins[index]))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    if let record {
                                        Text(record.title).font(.headline)
                                        SyncRecordDetails(
                                            record: record, fields: conflict.differingFields)
                                    } else {
                                        Text("Delete / keep absent").foregroundStyle(.red)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                        if let record {
                            DisclosureGroup("All details") {
                                SyncRecordDetails(record: record)
                                    .padding(.top, 8)
                            }
                            .font(.caption)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        selected ? MonMonTheme.accent.opacity(0.08) : MonMonTheme.canvas,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                selected ? MonMonTheme.accent : Color.clear, lineWidth: 1.5)
                    }
                }
            }
        }
        .padding(16)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func changes(_ title: LocalizedStringKey, rows: [SyncChange]) -> some View {
        DisclosureGroup {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedStringKey(row.kind))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(MonMonTheme.field, in: Capsule())
                        Spacer(minLength: 0)
                        Text(SyncLabels.type(row.after?.type ?? row.before?.type ?? ""))
                            .foregroundStyle(.secondary)
                    }.font(.caption)
                    Text(row.after?.title ?? row.before?.title ?? "")
                        .font(.headline)
                    DisclosureGroup("Details") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240))], alignment: .leading)
                        {
                            if let before = row.before {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Before").font(.caption.bold())
                                    SyncRecordDetails(record: before)
                                }
                            }
                            if let after = row.after {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("After").font(.caption.bold())
                                    SyncRecordDetails(record: after)
                                }
                            }
                        }
                        .padding(.top, 12)
                    }
                    .font(.callout)
                }
                .padding(16)
                .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                .padding(.vertical, 4)
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
            DisclosureGroup("Recent syncs") {
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
                        .padding(.vertical, 8)
                }
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
    var fields: [String]?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(fields ?? record.fields.keys.sorted().filter { $0 != "id" }, id: \.self) {
                key in
                let value = record.fields[key] ?? .null
                if fields != nil || value != .null {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SyncLabels.field(key))
                            .foregroundStyle(.secondary)
                        Text(
                            SyncLabels.formattedNumber(
                                value, field: key, locale: AppLanguage.stored.locale)
                                ?? sync.displayValue(value, field: key)
                        )
                        .font(fields == nil ? .caption : .callout.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(MonMonTheme.textPrimary)
                    }
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

extension SyncConflict {
    /// Missing values must remain visible when one version clears a field.
    var differingFields: [String] {
        let records = options.compactMap { $0 }
        let keys = Set(records.flatMap { $0.fields.keys }).subtracting(["id"])
        return keys.filter { key in
            options.contains(where: { $0 == nil })
                || records.dropFirst().contains {
                    ($0.fields[key] ?? .null) != (records.first?.fields[key] ?? .null)
                }
        }.sorted()
    }
}

enum SyncLabels {
    static func formattedNumber(_ value: SyncValue, field: String, locale: Locale) -> String? {
        let numericFields: Set<String> = [
            "amount", "openingBalance", "creditLimit", "principal", "units", "pricePerUnit",
            "currentPricePerUnit", "askPricePerUnit", "fee", "annualRate", "targetAmount",
            "exchangeRate", "costBasis",
        ]
        guard numericFields.contains(field) else { return nil }
        let number: Decimal?
        switch value {
        case .number(let decimal): number = decimal
        case .string(let text):
            number = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
        default: number = nil
        }
        return number?.formatted(.number.precision(.fractionLength(0...38)).locale(locale))
    }

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
