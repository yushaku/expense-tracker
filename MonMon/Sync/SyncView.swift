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
    @State private var didAutoReview = false

    var body: some View {
        @Bindable var sync = sync
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        statusCard

                        if let error = sync.errorMessage {
                            banner(
                                Text(error),
                                systemImage: "exclamationmark.triangle.fill",
                                tint: MonMonTheme.danger
                            )
                            .accessibilityIdentifier("sync-error")
                        }

                        if !sync.isPaired {
                            pairingCard
                        } else {
                            if let pairingCode = sync.pairingCode {
                                qrCard(pairingCode)
                            }

                            if sync.plan != nil {
                                review
                            }
                        }

                        if sync.hasPending {
                            banner(
                                Text(
                                    "A sync is unfinished. Reconnect the paired device to finish it. Data already saved will not be applied twice."
                                ),
                                systemImage: "clock.arrow.circlepath",
                                tint: MonMonTheme.savings
                            )
                        }

                        historyCard
                        aboutCard
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .compactRootNavigationTitle("Device Sync")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close", systemImage: "xmark") {
                        sync.disconnect()
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .tint(MonMonTheme.textSecondary)
                    .disabled(sync.writesLocked)
                    .accessibilityIdentifier("sync-close")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actions
            }
            .interactiveDismissDisabled(sync.writesLocked)
            .task {
                sync.connectIfPaired()
                // The app may have connected long before this screen opened.
                reactToPhase(sync.phase)
            }
            .onChange(of: sync.phase) { _, phase in reactToPhase(phase) }
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
                .appSheet(isPresented: $showScanner) {
                    SyncQRScanner { result in
                        showScanner = false
                        if let result { sync.acceptPairing(result) }
                    }
                }
            #endif
        }
        .tint(MonMonTheme.accent)
        #if os(macOS)
            .frame(width: 720, height: 740)
        #endif
        .privacySensitive()
        .accessibilityHidden(appLock.isLocked)
        .overlay {
            if appLock.isLocked {
                MonMonTheme.canvas.overlay {
                    Button("Unlock MonMon") { Task { _ = await appLock.authenticate() } }
                        .buttonStyle(.prominentAction)
                }
            }
        }
    }

    /// Comparing reads both devices and writes nothing, and every change still
    /// waits for Apply on both sides. So once two paired devices are on the
    /// air, the review opens itself rather than asking for the same tap twice.
    /// The host leads, so the two can never both be the initiator.
    private func reactToPhase(_ phase: SyncCoordinator.Phase) {
        if phase == .idle || phase == .interrupted {
            didAutoReview = false
            return
        }

        guard phase == .connected, !didAutoReview, sync.isHost, sync.canStart else { return }

        didAutoReview = true
        sync.startSync()
    }

    // MARK: - Status

    private var statusCard: some View {
        HStack(spacing: 14) {
            statusIcon
                .frame(width: 48, height: 48)
                .background(
                    MonMonTheme.accent.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(sync.isPaired ? LocalizedStringKey(sync.phase.rawValue) : "Pair your devices")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textPrimary)

                if !sync.peerName.isEmpty {
                    Text(sync.peerName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                if let statusHint {
                    Text(statusHint)
                        .font(.subheadline)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .appCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sync-status")
    }

    @ViewBuilder
    private var statusIcon: some View {
        if [.waiting, .comparing, .applying].contains(sync.phase) {
            ProgressView()
                .tint(MonMonTheme.accent)
        } else {
            Image(
                systemName: sync.phase == .complete
                    ? "checkmark.circle.fill" : "laptopcomputer.and.iphone"
            )
            .font(.title3.weight(.semibold))
            .foregroundStyle(MonMonTheme.accent)
        }
    }

    private var statusHint: LocalizedStringKey? {
        if !sync.isPaired {
            return "Keep MonMon open on your Mac and iPhone, using the same Wi-Fi."
        }

        if sync.phase == .review {
            return "Choose the version to keep. Nothing is saved until you apply."
        }

        if sync.phase == .waiting {
            return "Keep MonMon open on your Mac and iPhone, using the same Wi-Fi."
        }

        return nil
    }

    // MARK: - Pairing

    private var pairingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Pair your devices", systemImage: "qrcode")

            #if os(macOS)
                Button("Pair an iPhone", systemImage: "qrcode") { sync.createPairing() }
                    .buttonStyle(.prominentAction)
            #else
                Button("Scan Mac pairing code", systemImage: "qrcode.viewfinder") {
                    showScanner = true
                }
                .buttonStyle(.prominentAction)
            #endif

            Divider()
                .overlay(MonMonTheme.border)

            disclosure("Enter pairing code manually", systemImage: "keyboard") {
                VStack(alignment: .leading, spacing: 12) {
                    SecureField("Pairing code", text: $code)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(MonMonTheme.field, in: .rect(cornerRadius: 12))

                    Button("Pair") {
                        sync.acceptPairing(code)
                        code = ""
                    }
                    .buttonStyle(.prominentAction)
                    .disabled(code.isEmpty)
                }
                .padding(.top, 12)
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func qrCard(_ value: String) -> some View {
        if let image = Self.qrImage(value) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Scan this code in MonMon on your iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Image(decorative: image, scale: 1)
                    .interpolation(.none).resizable().scaledToFit()
                    .frame(maxWidth: 240)
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Pairing QR code")

                disclosure("Show pairing code", systemImage: "number") {
                    Text(value)
                        .font(.caption.monospaced())
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .textSelection(.enabled)
                        .padding(.top, 12)
                }
            }
            .appCard()
        }
    }

    // MARK: - Review

    @ViewBuilder
    private var review: some View {
        if let plan = sync.plan {
            if !plan.conflicts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        sectionHeader("Choose versions", systemImage: "arrow.triangle.branch")

                        Spacer(minLength: 8)

                        Text(
                            "\(plan.conflicts.count - unresolvedCount) of \(plan.conflicts.count) selected"
                        )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MonMonTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(MonMonTheme.accent.opacity(0.16), in: Capsule())
                    }

                    Text("iPhone versions are selected by default. You can change any selection.")
                        .font(.subheadline)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
                .appCard()
            }

            ForEach(plan.conflicts) { conflict in
                conflictCard(conflict)
            }

            if sync.canApply {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("Changes to apply", systemImage: "list.bullet.rectangle")

                        Text("What each device saves when you apply.")
                            .font(.subheadline)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }

                    changes(on: ownDeviceName, rows: sync.previewLocal)

                    Divider()
                        .overlay(MonMonTheme.border)

                    changes(on: peerDeviceName, rows: sync.previewRemote)
                }
                .appCard()
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
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                HStack(spacing: 12) {
                    if sync.plan != nil {
                        Button("Cancel") { sync.cancelReview() }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MonMonTheme.textSecondary)
                            .frame(minHeight: 44)
                            .disabled(sync.hasPending)

                        Spacer(minLength: 0)

                        if sync.phase == .review {
                            Button("Apply to both devices") { sync.apply() }
                                .buttonStyle(.prominentAction)
                                .disabled(!sync.canApply)
                                .accessibilityIdentifier("sync-apply")
                        }
                    } else if sync.canStart {
                        Spacer(minLength: 0)

                        Button("Review changes", systemImage: "arrow.triangle.2.circlepath") {
                            sync.startSync()
                        }
                        .buttonStyle(.prominentAction)
                        .accessibilityIdentifier("sync-start")
                    } else if sync.phase == .idle || sync.phase == .interrupted {
                        Spacer(minLength: 0)

                        Button("Connect", systemImage: "wifi") { sync.connect() }
                            .buttonStyle(.prominentAction)
                    } else {
                        Text(LocalizedStringKey(sync.phase.rawValue))
                            .font(.subheadline)
                            .foregroundStyle(MonMonTheme.textSecondary)

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonMonTheme.surface)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(MonMonTheme.border)
                    .frame(height: 1)
            }
        }
    }

    private func conflictCard(_ conflict: SyncConflict) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(SyncLabels.type(conflict.options.compactMap { $0 }.first?.type ?? ""))
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(MonMonTheme.textSecondary)

                    Text(conflict.options.compactMap { $0 }.first?.title ?? "Deleted")
                        .font(.headline)
                        .foregroundStyle(MonMonTheme.textPrimary)
                }

                Spacer(minLength: 0)

                if sync.choices[conflict.id] != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(MonMonTheme.accent)
                        .accessibilityLabel("Selected")
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                ForEach(conflict.optionIDs, id: \.self) { optionID in
                    let index = conflict.optionIDs.firstIndex(of: optionID) ?? 0
                    let record = conflict.options[index]
                    let selected = sync.choices[conflict.id] == index

                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            sync.choices[conflict.id] = index
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(
                                        selected ? MonMonTheme.accent : MonMonTheme.textMuted
                                    )

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(deviceLabel(conflict.origins[index]))
                                        .font(.caption.weight(.semibold))
                                        .tracking(0.6)
                                        .foregroundStyle(MonMonTheme.textSecondary)

                                    if let record {
                                        Text(record.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(MonMonTheme.textPrimary)

                                        SyncRecordDetails(
                                            record: record, fields: conflict.differingFields)
                                    } else {
                                        Text("Delete / keep absent")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(MonMonTheme.danger)
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
                            disclosure("All details", systemImage: "list.bullet") {
                                SyncRecordDetails(record: record)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        selected ? MonMonTheme.accent.opacity(0.12) : MonMonTheme.field,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                selected ? MonMonTheme.accent : Color.clear, lineWidth: 1.5)
                    }
                    .animation(.snappy(duration: 0.2), value: selected)
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func changes(on device: String, rows: [SyncChange]) -> some View {
        if rows.isEmpty {
            Text("Nothing changes on \(device)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(rows) { row in
                        changeRow(row)
                    }
                }
                .padding(.top, 12)
            } label: {
                HStack(spacing: 12) {
                    Text("Will change on \(device)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.textPrimary)

                    Spacer(minLength: 8)

                    Text(rows.count, format: .number)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MonMonTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(MonMonTheme.accent.opacity(0.16), in: Capsule())
                }
            }
            .tint(MonMonTheme.accent)
        }
    }

    private func changeRow(_ row: SyncChange) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(LocalizedStringKey(row.kind))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MonMonTheme.surface, in: Capsule())

                Spacer(minLength: 0)

                Text(SyncLabels.type(row.after?.type ?? row.before?.type ?? ""))
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Text(row.after?.title ?? row.before?.title ?? "")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.textPrimary)

            disclosure("Details", systemImage: "list.bullet") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240))], alignment: .leading) {
                    if let before = row.before {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Before")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MonMonTheme.textSecondary)

                            SyncRecordDetails(record: before)
                        }
                    }

                    if let after = row.after {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("After")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MonMonTheme.textSecondary)

                            SyncRecordDetails(record: after)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonMonTheme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - History and help

    @ViewBuilder
    private var historyCard: some View {
        if !sync.reports.isEmpty {
            disclosure("Recent syncs", systemImage: "clock.arrow.circlepath") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(sync.reports) { report in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.peerName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MonMonTheme.textPrimary)

                            Text(
                                report.completedAt,
                                format: .dateTime.day().month().hour().minute()
                            )
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)

                            Text(
                                "Added: \(report.added) · Updated: \(report.updated) · Deleted: \(report.deleted)"
                            )
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)

                            if let recovery = sync.store.recoveryFile(for: report.id) {
                                ShareLink("Export recovery backup", item: recovery)
                                    .font(.caption.weight(.semibold))
                                    .padding(.top, 2)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                }
                .padding(.top, 12)
            }
            .appCard()
        }
    }

    private var aboutCard: some View {
        disclosure("About device sync", systemImage: "info.circle") {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    "Open MonMon on both devices on the same Wi-Fi. Review changes before applying them to both devices."
                )

                Text(
                    "Drafts and device settings stay on this device. Devices on guest Wi-Fi may be unable to discover each other. Allow Local Network access in system settings if discovery is blocked."
                )

                if sync.isPaired && !sync.hasPending && sync.plan == nil {
                    Button("Unpair", role: .destructive) { confirmUnpair = true }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.danger)
                        .frame(minHeight: 44)
                }
            }
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
        }
        .appCard()
    }

    // MARK: - Shared pieces

    private var ownDeviceName: String {
        SyncCoordinator.deviceName
    }

    private var peerDeviceName: String {
        sync.peerName.isEmpty
            ? AppText.string(key: "Other device", in: AppLanguage.stored.locale) : sync.peerName
    }

    /// "This device" and "Other device" meant provenance on a conflict card and
    /// destination in the change list, which is what made both hard to read.
    /// Everything the owner sees now names the machine it is talking about.
    private func deviceLabel(_ origin: String) -> String {
        switch origin {
        case "This device":
            return ownDeviceName
        case "Other device":
            return peerDeviceName
        default:
            return AppText.string(key: origin, in: AppLanguage.stored.locale)
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(MonMonTheme.textPrimary)
    }

    /// The app has no expanding rows of its own, so the system disclosure is
    /// dressed to read like a card's own section header.
    private func disclosure<Content: View>(
        _ title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let body = content()

        return DisclosureGroup {
            body
        } label: {
            sectionHeader(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
        }
        .tint(MonMonTheme.accent)
    }

    private func banner(_ text: Text, systemImage: String, tint: Color) -> some View {
        Label {
            text
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.subheadline)
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            tint.opacity(0.14),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private static func qrImage(_ value: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}

/// One record read as label/value rows, the same two-column reading as the
/// app's own transaction details — a stack of stacked paragraphs was the part
/// of a conflict nobody could scan.
private struct SyncRecordDetails: View {
    @Environment(SyncCoordinator.self) private var sync
    let record: SyncRecord
    var fields: [String]?

    /// Money first, then when and what, then what it points at. Anything
    /// unlisted keeps its alphabetical place after these, and `createdAt`
    /// closes the list: it is provenance, not something the owner entered.
    private static let order = [
        "kind", "amount", "currencyCode", "occurredAt", "name", "title", "note",
        "accountID", "categoryID", "tripWorkspaceID",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(shownKeys.enumerated()), id: \.element) { index, key in
                if index > 0 {
                    Divider()
                        .overlay(MonMonTheme.border)
                }

                row(key)
            }
        }
    }

    /// A requested field stays even when it is empty, so a version that clears
    /// a value still shows the value it cleared.
    private var shownKeys: [String] {
        let requested = fields ?? record.fields.keys.sorted().filter { $0 != "id" }
        let kept = requested.filter { fields != nil || (record.fields[$0] ?? .null) != .null }

        return kept.enumerated()
            .sorted { (Self.rank($0.element), $0.offset) < (Self.rank($1.element), $1.offset) }
            .map(\.element)
    }

    private static func rank(_ key: String) -> Int {
        if key == "createdAt" {
            return order.count + 1
        }

        return order.firstIndex(of: key) ?? order.count
    }

    private func row(_ key: String) -> some View {
        let value = record.fields[key] ?? .null

        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(SyncLabels.field(key))
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)

            Spacer(minLength: 8)

            Text(
                SyncLabels.formattedNumber(value, field: key, locale: AppLanguage.stored.locale)
                    ?? sync.displayValue(value, field: key)
            )
            .font(fields == nil ? .caption.weight(.medium) : .subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(MonMonTheme.textPrimary)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
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
