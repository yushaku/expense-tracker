import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum MonMonBackupFilename {
    static func make(date: Date = .now, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "MonMon-backup-\(formatter.string(from: date)).json"
    }
}

enum MonMonBackupUserMessage {
    static func error(_ error: Error) -> String {
        if let error = error as? MonMonBackupValidationError {
            switch error {
            case .fileTooLarge:
                return "The selected backup is larger than 100 MB."
            case .invalidDocument:
                return "This isn’t a readable MonMon backup."
            case .unsupportedFormat:
                return "This JSON file is not a MonMon backup."
            case .unsupportedVersion:
                return "This backup needs a newer version of MonMon."
            case .wrongFlavour:
                return "This backup belongs to a different MonMon build."
            case .checksumMismatch:
                return "The backup is damaged or was edited."
            case .invalidPayload, .duplicateIdentifier, .invalidReference:
                return "The backup contains invalid or inconsistent data."
            }
        }

        if let error = error as? MonMonBackupServiceError {
            switch error {
            case .outputTooLarge:
                return "The backup is larger than 100 MB and wasn’t exported."
            case .recoveryFailure:
                return "MonMon couldn’t create the safety copy, so no data was changed."
            case .storeFailure:
                return
                    "MonMon couldn’t replace the local data. Your previous data is still available."
            case .invalidSnapshot:
                return "The selected backup is no longer valid. Choose the file again."
            }
        }

        return "MonMon couldn’t complete the backup operation. Try again."
    }
}

struct MonMonBackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw MonMonBackupValidationError.invalidDocument
        }
        self.data = data
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupRestoreView: View {
    @Environment(AppLock.self) private var appLock
    @Environment(CloudSync.self) private var cloudSync
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    @State private var isWorking = false
    @State private var isPresentingExportWarning = false
    @State private var isPresentingExporter = false
    @State private var isPresentingImporter = false
    @State private var exportDocument: MonMonBackupFileDocument?
    @State private var exportFilename = "MonMon-backup.json"
    @State private var selection: BackupRestoreSelection?
    @State private var operationError: String?
    @State private var notice: BackupRestoreNotice?
    @State private var hasRecovery = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(MonMonTheme.border)

            Text("Full backup")
                .font(.subheadline.weight(.semibold))

            Text(
                "Export or replace every account, transaction, category, budget jar, financial goal, trip workspace, recurring rule, saving, investment, transfer, and debt on this device."
            )
            .font(.caption)
            .foregroundStyle(MonMonTheme.textSecondary)

            Label(
                "Exported JSON is readable financial data. Keep it somewhere private.",
                systemImage: "exclamationmark.shield.fill"
            )
            .font(.caption)
            .foregroundStyle(MonMonTheme.textSecondary)

            HStack(spacing: 10) {
                Button {
                    isPresentingExportWarning = true
                } label: {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.prominentAction)
                .disabled(isWorking)
                .frame(minHeight: 44)
                .accessibilityIdentifier("backup-export")

                Button {
                    isPresentingImporter = true
                } label: {
                    Label("Restore Backup", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.danger)
                .frame(minHeight: 44)
                .disabled(isWorking)
                .accessibilityIdentifier("backup-restore")
            }

            if hasRecovery {
                Button {
                    prepareRecoveryPreview()
                } label: {
                    Label("Restore Previous Data", systemImage: "clock.arrow.circlepath")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.danger)
                .disabled(isWorking)
                .accessibilityIdentifier("backup-restore-previous")
            }

            if isWorking {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Working…")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
                .accessibilityIdentifier("backup-progress")
            }
        }
        .task { refreshRecoveryAvailability() }
        .alert("Export readable JSON?", isPresented: $isPresentingExportWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") { buildExport() }
        } message: {
            Text("Anyone who can open the file can read the financial data inside it.")
        }
        .fileExporter(
            isPresented: $isPresentingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            exportDocument = nil
            switch result {
            case .success:
                notice = BackupRestoreNotice(
                    message: localized("Backup exported."), isFailure: false)
            case let .failure(error):
                if !isCancellation(error) {
                    notice = BackupRestoreNotice(
                        message: localized(MonMonBackupUserMessage.error(error)),
                        isFailure: true
                    )
                }
            }
        }
        .fileImporter(isPresented: $isPresentingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case let .success(url):
                prepareImportedPreview(from: url)
            case let .failure(error):
                if !isCancellation(error) {
                    notice = BackupRestoreNotice(
                        message: localized(MonMonBackupUserMessage.error(error)),
                        isFailure: true
                    )
                }
            }
        }
        .appSheet(item: $selection) { selection in
            BackupRestorePreviewSheet(
                selection: selection,
                isWorking: isWorking,
                errorMessage: operationError,
                isCloudSyncEnabled: cloudSync.isEnabled,
                onCancel: { self.selection = nil },
                onRestore: performRestore
            )
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.isFailure ? "Backup failed" : "Backup"),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var service: MonMonBackupService {
        MonMonBackupService(container: modelContext.container)
    }

    private func buildExport() {
        guard !isWorking else { return }
        isWorking = true
        Task { @MainActor in
            await Task.yield()
            defer { isWorking = false }
            do {
                try modelContext.save()
                let now = Date.now
                exportDocument = MonMonBackupFileDocument(
                    data: try service.exportData(exportedAt: now))
                exportFilename = MonMonBackupFilename.make(date: now)
                isPresentingExporter = true
            } catch {
                notice = BackupRestoreNotice(
                    message: localized(MonMonBackupUserMessage.error(error)),
                    isFailure: true
                )
            }
        }
    }

    private func prepareImportedPreview(from url: URL) {
        guard !isWorking else { return }
        isWorking = true
        Task { @MainActor in
            await Task.yield()
            defer { isWorking = false }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let fileSize = try checkedFileSize(at: url)
                let data = try MonMonBackupFileReader.read(url)
                let validated = try service.preview(data)
                selection = BackupRestoreSelection(
                    validated: validated,
                    byteCount: fileSize ?? data.count,
                    currentRecordCount: try service.makeDocument().payload.recordCount
                )
                operationError = nil
            } catch {
                notice = BackupRestoreNotice(
                    message: localized(MonMonBackupUserMessage.error(error)),
                    isFailure: true
                )
            }
        }
    }

    private func prepareRecoveryPreview() {
        guard !isWorking else { return }
        isWorking = true
        Task { @MainActor in
            await Task.yield()
            defer { isWorking = false }
            do {
                let validated = try service.loadRecovery()
                let byteCount =
                    try service.recoveryURL.resourceValues(forKeys: [.fileSizeKey])
                    .fileSize ?? 0
                selection = BackupRestoreSelection(
                    validated: validated,
                    byteCount: byteCount,
                    currentRecordCount: try service.makeDocument().payload.recordCount
                )
                operationError = nil
            } catch {
                refreshRecoveryAvailability()
                notice = BackupRestoreNotice(
                    message: localized(MonMonBackupUserMessage.error(error)),
                    isFailure: true
                )
            }
        }
    }

    private func performRestore() {
        guard let selection, !isWorking else { return }
        isWorking = true
        operationError = nil
        Task { @MainActor in
            await Task.yield()
            defer { isWorking = false }

            if appLock.isEnabled {
                let authenticated = await appLock.authenticate(
                    reason: "Restore and replace all MonMon data."
                )
                guard authenticated else {
                    operationError =
                        appLock.failureMessage ?? localized("Authentication is required.")
                    return
                }
            }

            do {
                try modelContext.save()
                _ = try service.restore(selection.validated)
                hasRecovery = true
                self.selection = nil
                notice = BackupRestoreNotice(
                    message: localized(
                        cloudSync.isEnabled
                            ? "Local restore complete. iCloud will sync this state separately."
                            : "Local restore complete."
                    ),
                    isFailure: false
                )
            } catch {
                operationError = localized(MonMonBackupUserMessage.error(error))
            }
        }
    }

    private func refreshRecoveryAvailability() {
        hasRecovery = service.hasValidRecovery
    }

    private func checkedFileSize(at url: URL) throws -> Int? {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        if let size, size > MonMonBackupValidator.maximumByteCount {
            throw MonMonBackupValidationError.fileTooLarge
        }
        return size
    }

    private func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }

    private func localized(_ key: String) -> String {
        AppText.string(key: key, in: locale)
    }
}

private struct BackupRestoreSelection: Identifiable {
    let id = UUID()
    let validated: ValidatedMonMonBackup
    let byteCount: Int
    let currentRecordCount: Int
}

private struct BackupRestoreNotice: Identifiable {
    let id = UUID()
    let message: String
    let isFailure: Bool
}

private struct BackupRestorePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selection: BackupRestoreSelection
    let isWorking: Bool
    let errorMessage: String?
    let isCloudSyncEnabled: Bool
    let onCancel: () -> Void
    let onRestore: () -> Void
    @State private var isConfirmingRestore = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metadata
                    recordCounts

                    if !selection.validated.warnings.isEmpty {
                        Label(
                            "Some optional links or saved defaults are stale. MonMon will clear only those defaults and preserve supported records.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                    }

                    if isCloudSyncEnabled {
                        Label(
                            "Close MonMon on other devices. Restore here, let this device sync, then reopen the others.",
                            systemImage: "icloud.and.arrow.up"
                        )
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.danger)
                            .accessibilityIdentifier("backup-restore-error")
                    }

                    Button(role: .destructive) {
                        isConfirmingRestore = true
                    } label: {
                        Label("Restore and Replace", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)
                    .accessibilityIdentifier("backup-restore-confirm")

                    if isWorking {
                        ProgressView("Restoring…")
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("backup-restore-progress")
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(MonMonTheme.canvas)
            .navigationTitle("Restore Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isWorking)
                    .accessibilityIdentifier("backup-restore-cancel")
                }
            }
            .alert("Replace all local data?", isPresented: $isConfirmingRestore) {
                Button("Cancel", role: .cancel) {}
                Button("Restore and Replace", role: .destructive, action: onRestore)
            } message: {
                Text(
                    "The selected snapshot becomes the complete local dataset. MonMon will create a private safety copy first."
                )
            }
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backup details")
                .font(.headline)
            detailRow("Created", value: selection.validated.preview.exportedAt.formatted())
            detailRow("App version", value: selection.validated.preview.appVersion)
            detailRow("Build", value: selection.validated.preview.flavour.rawValue.uppercased())
            detailRow(
                "File size",
                value: ByteCountFormatter.string(
                    fromByteCount: Int64(selection.byteCount), countStyle: .file)
            )
        }
    }

    private var recordCounts: some View {
        let counts = selection.validated.preview.counts
        return VStack(alignment: .leading, spacing: 8) {
            Text("Records")
                .font(.headline)
            detailRow("Current total", value: selection.currentRecordCount.formatted())
            detailRow(
                "Incoming total", value: selection.validated.preview.incomingRecordCount.formatted()
            )
            Divider()
            detailRow("Accounts", value: counts.accounts.formatted())
            detailRow("Budget jars", value: counts.budgetJars.formatted())
            detailRow("Financial goals", value: counts.goals.formatted())
            detailRow("Trip workspaces", value: counts.tripWorkspaces.formatted())
            detailRow("Transactions", value: counts.transactions.formatted())
            detailRow("Categories", value: counts.categories.formatted())
            detailRow("Recurring rules", value: counts.recurringRules.formatted())
            detailRow("Pending captures", value: counts.pendingCaptures.formatted())
            detailRow("Transfers", value: counts.transfers.formatted())
            detailRow("Savings deposits", value: counts.savingsDeposits.formatted())
            detailRow("Savings withdrawals", value: counts.savingsWithdrawals.formatted())
            detailRow("Fund & gold instruments", value: counts.fundInstruments.formatted())
            detailRow("Fund & gold holdings", value: counts.fundHoldings.formatted())
            detailRow("Fund & gold sales", value: counts.fundSales.formatted())
            detailRow("Debts", value: counts.debts.formatted())
            detailRow("Debt payments", value: counts.debtPayments.formatted())
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(title))
                .foregroundStyle(MonMonTheme.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
