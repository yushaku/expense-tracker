import SwiftUI

struct StatementImportInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Bindable var inbox: StatementImportInbox

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("Import Inbox")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("close-import-inbox")
                }
            }
            .accessibilityIdentifier("import-inbox")
        }
        .tint(MonMonTheme.accent)
        .task { await inbox.refresh() }
        .alert(
            "Statement review complete",
            isPresented: isCompletionPresented,
            presenting: inbox.completionReport
        ) { _ in
            Button("Done") { inbox.clearCompletionReport() }
                .accessibilityIdentifier("dismiss-statement-import-result")
        } message: { report in
            VStack(alignment: .leading, spacing: 4) {
                Text("Created transactions: \(report.createdTransactionCount)")
                Text("Created transfers: \(report.createdTransferCount)")
                Text("Linked records: \(report.linkedCount)")
                if report.skippedCount > 0 {
                    Text("Skipped: \(report.skippedCount)")
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch inbox.listPhase {
        case .idle, .loading:
            progress
        case .loaded(let statements) where statements.isEmpty:
            emptyState
        case .loaded(let statements):
            statementList(statements)
        case .failed(let failure):
            failureState(failure)
        }
    }

    private var progress: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Checking shared statements…")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .accessibilityIdentifier("import-inbox-loading")
    }

    private var isCompletionPresented: Binding<Bool> {
        Binding(
            get: { inbox.completionReport != nil },
            set: { isPresented in
                if !isPresented {
                    inbox.clearCompletionReport()
                }
            }
        )
    }

    private var emptyState: some View {
        messageCard(
            title: "No statements waiting",
            message: "Export a PDF from your bank or Files, then share it to MonMon.",
            systemImage: "tray",
            tint: MonMonTheme.accent
        ) {
            EmptyView()
        }
        .padding(20)
        .accessibilityIdentifier("import-inbox-empty")
    }

    private func failureState(_ failure: StatementImportFailure) -> some View {
        messageCard(
            title: "Import Inbox unavailable",
            message: failure.message,
            systemImage: "exclamationmark.triangle.fill",
            tint: MonMonTheme.danger
        ) {
            Button("Try Again") {
                Task { await inbox.refresh() }
            }
            .buttonStyle(.prominentAction)
            .accessibilityIdentifier("retry-import-inbox")
        }
        .padding(20)
        .accessibilityIdentifier("import-inbox-error")
    }

    private func statementList(_ statements: [StagedBankStatement]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("Waiting for review")
                    .font(.title3.weight(.semibold))

                Text("Nothing is added to your records until you review a statement.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)

                ForEach(Array(statements.enumerated()), id: \.element.id) { index, statement in
                    NavigationLink {
                        StatementImportPreviewView(inbox: inbox, staged: statement)
                    } label: {
                        statementRow(statement)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("import-statement-\(index)")
                }
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }

    private func statementRow(_ statement: StagedBankStatement) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.richtext.fill")
                .font(.title3)
                .foregroundStyle(MonMonTheme.bank)
                .frame(width: 44, height: 44)
                .background(MonMonTheme.bank.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(statement.originalFilename)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(MonMonTheme.textPrimary)

                Text("Received \(receivedDate(statement)) · \(fileSize(statement))")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MonMonTheme.textMuted)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .padding(14)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens statement review")
    }

    private func receivedDate(_ statement: StagedBankStatement) -> String {
        statement.createdAt.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)
        )
    }

    private func fileSize(_ statement: StagedBankStatement) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(statement.byteCount),
            countStyle: .file
        )
    }

    private func messageCard<Action: View>(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 64, height: 64)
                .background(tint.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            action()
        }
        .frame(maxWidth: MonMonTheme.maxContentWidth)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }
}

extension StatementImportFailure {
    var message: LocalizedStringKey {
        switch self {
        case .appGroupUnavailable:
            "MonMon cannot access its shared inbox. Check the installed app and try again."
        case .unsupportedPDF:
            "This staged file is not a valid PDF. Remove it and share the original PDF again."
        case .oversizedFile:
            "This PDF is larger than 25 MB and cannot be reviewed."
        case .unreadableInput:
            "MonMon cannot read this staged PDF. Share the original file again."
        case .malformedStagedItem:
            "This staged copy is damaged. Remove it and share the original PDF again."
        case .fileSystem:
            "MonMon could not read its local inbox. Please try again."
        case .unsupportedFormat:
            "This bank statement format is not supported yet."
        case .encryptedDocument:
            "This PDF is password protected. Export an unlocked statement and share it again."
        case .missingTextLayer:
            "This PDF contains images instead of selectable text. OCR is not supported yet."
        case .unrecognizedLayout:
            "The bank changed this statement layout, so MonMon cannot read it safely."
        case .invalidStatementMetadata:
            "MonMon could not verify the account, currency, or statement period."
        case .noTransactionRows:
            "MonMon found no transaction rows in this statement."
        case .unknown:
            "MonMon could not review this statement. Please try again."
        }
    }
}
