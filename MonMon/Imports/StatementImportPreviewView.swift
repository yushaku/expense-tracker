import SwiftData
import SwiftUI

struct StatementImportPreviewView: View {
    @Environment(\.appDateFormat) private var dateFormat

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]
    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]
    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]
    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

    @AppStorage(TransactionDefaults.categoryStorageKey)
    private var defaultExpenseCategoryValue = ""
    @AppStorage(TransactionDefaults.incomeCategoryStorageKey)
    private var defaultIncomeCategoryValue = ""
    @AppStorage(TransactionDefaults.accountStorageKey)
    private var defaultAccountValue = ""

    @Bindable var inbox: StatementImportInbox
    let staged: StagedBankStatement

    @State private var isConfirmingRemoval = false
    @State private var isRemoving = false
    @State private var review: StatementImportReview?
    @State private var editorSelection: RowEditorSelection?
    @State private var commitConfirmation: StatementImportCommitConfirmation?

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            content
        }
        .navigationTitle("Statement Review")
        .navigationBarBackButtonHidden(isReviewCommitting)
        .interactiveDismissDisabled(isReviewCommitting)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    isConfirmingRemoval = true
                } label: {
                    Label("Remove Statement", systemImage: "trash")
                }
                .disabled(isRemoving || review?.isEditingAllowed == false)
                .accessibilityIdentifier("remove-import-statement")
            }
        }
        .confirmationDialog(
            "Remove this statement?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove Statement", role: .destructive) {
                removeStatement()
            }
            .accessibilityIdentifier("confirm-remove-import-statement")

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The staged PDF will be deleted. No financial records are affected.")
        }
        .confirmationDialog(
            commitConfirmationTitle,
            isPresented: isCommitConfirmationPresented,
            titleVisibility: .visible
        ) {
            if let confirmation = commitConfirmation, let review {
                if confirmation.removesReviewedStatement {
                    Button("Remove reviewed statement", role: .destructive) {
                        confirmCommit(review)
                    }
                    .accessibilityIdentifier("confirm-remove-reviewed-statement")
                } else {
                    Button(commitActionTitle(confirmation)) {
                        confirmCommit(review)
                    }
                    .accessibilityIdentifier("confirm-import-statement")
                }
            }

            Button("Cancel", role: .cancel) {
                commitConfirmation = nil
            }
        } message: {
            if let confirmation = commitConfirmation {
                confirmationCounts(confirmation)
            }
        }
        .task(id: staged.id) { await inbox.loadPreview(staged) }
        .appSheet(item: $editorSelection) { selection in
            if let review,
                let rowIndex = review.rows.firstIndex(where: { $0.id == selection.id })
            {
                StatementImportRowEditorView(
                    review: review,
                    rowIndex: rowIndex,
                    categories: categories
                )
            }
        }
        .onDisappear {
            editorSelection = nil
            commitConfirmation = nil
            review = nil
            inbox.clearPreview()
        }
        .accessibilityIdentifier("import-statement-preview")
    }

    @ViewBuilder
    private var content: some View {
        switch inbox.previewPhase {
        case .loaded(let preview) where preview.staged.id == staged.id:
            if let review, review.staged.id == staged.id {
                reviewContent(review)
            } else {
                progress.task { prepareReview(preview) }
            }
        case .failed(let failedStaged, let failure) where failedStaged.id == staged.id:
            failureContent(failure)
        default:
            progress
        }
    }

    private var progress: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Reading statement locally…")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .accessibilityIdentifier("import-preview-loading")
    }

    private func failureContent(_ failure: StatementImportFailure) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.danger)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.danger.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            Text("Couldn’t read this statement")
                .font(.title3.weight(.semibold))

            Text(failure.message)
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button("Try Again") {
                Task { await inbox.loadPreview(staged) }
            }
            .buttonStyle(.prominentAction)
            .accessibilityIdentifier("retry-import-preview")
        }
        .padding(24)
        .accessibilityIdentifier("import-preview-error")
    }

    private func reviewContent(_ review: StatementImportReview) -> some View {
        ScrollViewReader { proxy in
            List {
                summaryCard(review.statement)
                    .importReviewListRow(top: 16, bottom: 0)

                statementAccountCard(review)
                    .importReviewListRow(top: 12, bottom: 0)

                if !review.statement.issues.isEmpty {
                    issuesCard(review.statement.issues)
                        .importReviewListRow(top: 12, bottom: 0)
                }

                commitStatusCard(review)
                    .id("import-review-status")

                if !review.invalidRows.isEmpty {
                    Section {
                        Text(
                            "These transactions will not be imported. Open a row to review its reason."
                        )
                        .font(.subheadline)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .importReviewListRow(top: 0, bottom: 12)
                        ForEach(review.invalidRows) { row in
                            candidateRow(
                                row, index: review.rows.firstIndex { $0.id == row.id } ?? 0,
                                review: review
                            )
                            .disabled(!review.isEditingAllowed)
                            .importReviewListRow(top: 0, bottom: 12)
                        }
                    } header: {
                        Text("Needs attention: \(review.invalidRows.count)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(MonMonTheme.danger)
                            .textCase(nil)
                    }
                }

                Section {
                    ForEach(review.validRows) { row in
                        candidateRow(
                            row, index: review.rows.firstIndex { $0.id == row.id } ?? 0,
                            review: review
                        )
                        .disabled(!review.isEditingAllowed)
                        .importReviewListRow(top: 0, bottom: 12)
                    }
                } header: {
                    HStack {
                        Text("Transactions")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text("Selected: \(review.selectedCount)")
                            .font(.subheadline)
                    }
                    .foregroundStyle(MonMonTheme.textPrimary)
                    .textCase(nil)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MonMonTheme.canvas)
            .safeAreaInset(edge: .bottom) {
                commitFooter(review)
            }
            .onChange(of: review.phase) { _, phase in
                if case .failed = phase {
                    proxy.scrollTo("import-review-status", anchor: .top)
                }
            }
        }
    }

    private func statementAccountCard(_ review: StatementImportReview) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Statement account", systemImage: "creditcard.fill")
                    .font(.headline)

                Picker(
                    "Statement account",
                    selection: Binding(
                        get: { review.statementAccountID },
                        set: { review.selectStatementAccount($0) }
                    )
                ) {
                    Text("Choose").tag(nil as UUID?)
                    ForEach(vndAccounts) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
                .disabled(!review.isEditingAllowed)
                .accessibilityIdentifier("statement-import-account")

                if review.statementAccountID == nil {
                    Label(
                        "Choose an account for the imported transactions.",
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.danger)
                    .accessibilityIdentifier("statement-import-account-required")
                }
            }
        }
        .accessibilityIdentifier("statement-import-account-card")
    }

    private func summaryCard(_ statement: ParsedBankStatement) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "building.columns.fill")
                        .font(.title3)
                        .foregroundStyle(MonMonTheme.bank)
                        .frame(width: 44, height: 44)
                        .background(
                            MonMonTheme.bank.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(bankName(statement.bank))
                            .font(.headline)

                        if let suffix = statement.accountLastFour {
                            Text("Account •••• \(suffix)")
                                .font(.subheadline)
                                .foregroundStyle(MonMonTheme.textSecondary)
                        }

                        Text(period(statement.period))
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }

                    Spacer(minLength: 8)

                    completenessLabel(statement.isComplete)
                }

                Divider().overlay(MonMonTheme.border)

                HStack(spacing: 12) {
                    total(
                        title: "Income",
                        amount: statement.parsedTotals.credit,
                        tint: MonMonTheme.gain
                    )
                    total(
                        title: "Expense",
                        amount: statement.parsedTotals.debit,
                        tint: MonMonTheme.danger
                    )
                }

                Text("\(statement.candidates.count) transactions ready for review")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .accessibilityIdentifier("import-preview-summary")
    }

    private func completenessLabel(_ isComplete: Bool) -> some View {
        Label(
            isComplete ? "Complete" : "Needs attention",
            systemImage: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(isComplete ? MonMonTheme.gain : MonMonTheme.danger)
        .multilineTextAlignment(.trailing)
    }

    private func total(title: LocalizedStringKey, amount: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(VNDCurrency.format(amount))
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func issuesCard(_ issues: [BankStatementIssue]) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(MonMonTheme.danger)

                Text("MonMon did not silently discard uncertain statement data.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)

                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    Label(issueMessage(issue), systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }
        }
        .accessibilityIdentifier("import-preview-issues")
    }

    @ViewBuilder
    private func commitStatusCard(_ review: StatementImportReview) -> some View {
        switch review.phase {
        case .reviewing:
            EmptyView()
        case .committing:
            card {
                HStack(spacing: 12) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saving reviewed records…")
                            .font(.headline)
                        Text("Keep MonMon open until this finishes.")
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("statement-import-saving")
            .importReviewListRow(top: 12, bottom: 0)
        case .saved:
            card {
                Label("Records saved", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(MonMonTheme.gain)
            }
            .accessibilityIdentifier("statement-import-saved")
            .importReviewListRow(top: 12, bottom: 0)
        case .cleanupNeeded:
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "Records saved; statement cleanup needed",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(MonMonTheme.danger)

                    Text(
                        "Your financial records are safe. Retry removing the staged PDF; this will not create duplicates."
                    )
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                }
            }
            .accessibilityIdentifier("statement-import-cleanup-needed")
            .importReviewListRow(top: 12, bottom: 0)
        case .failed(let failure):
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Import stopped — nothing saved", systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(MonMonTheme.danger)

                    Text(reviewFailureMessage(failure))
                        .font(.subheadline)
                        .foregroundStyle(MonMonTheme.textSecondary)

                    Text(
                        "No transactions from this attempt were saved. Your selections are still available below."
                    )
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                }
            }
            .accessibilityIdentifier("statement-import-save-failed")
            .importReviewListRow(top: 12, bottom: 0)
        }
    }

    private func candidateRow(
        _ row: ReconciledImportRow, index: Int, review: StatementImportReview
    ) -> some View {
        let candidate = row.candidate
        let status = rowStatus(row, review: review)
        return HStack(alignment: .top, spacing: 0) {
            Button {
                review.setSelected(!row.isSelected, forCandidateID: row.id)
            } label: {
                Image(systemName: row.isSelected ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(row.isSelected ? MonMonTheme.bank : MonMonTheme.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(row.disposition.isExact || review.validationIssue(for: row) != nil)
            .accessibilityLabel("Import transaction: \(candidate.note)")
            .accessibilityValue(row.isSelected ? Text("Selected") : Text("Not selected"))
            .accessibilityAddTraits(row.isSelected ? [.isSelected] : [])
            .accessibilityIdentifier("select-import-candidate-\(index)")

            Button {
                editorSelection = RowEditorSelection(id: row.id)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(candidate.kind.signLabel)\(VNDCurrency.format(candidate.amount))")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(
                                candidate.kind == .income ? MonMonTheme.gain : MonMonTheme.danger
                            )
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MonMonTheme.textMuted)
                            .accessibilityHidden(true)
                    }
                    Text(candidate.note.isEmpty ? "No description" : candidate.note)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.textPrimary)
                    Label(status.title, systemImage: status.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(status.tint)
                    Text(dateFormat.dateTime(candidate.occurredAt, in: locale))
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                    Text("Reference \(candidate.sourceReference) · Page \(candidate.sourcePage)")
                        .font(.caption2)
                        .foregroundStyle(MonMonTheme.textMuted)
                }
                .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Edit category and note")
            .accessibilityIdentifier("import-candidate-\(index)")
        }
        .padding(14)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private func commitFooter(_ review: StatementImportReview) -> some View {
        VStack(spacing: 8) {
            if let blocker = commitBlocker(review) {
                Text(blocker)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("statement-import-commit-blocker")
            }

            switch review.phase {
            case .cleanupNeeded:
                Button {
                    retryCleanup(review)
                } label: {
                    Label("Retry cleanup", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.prominentAction)
                .accessibilityIdentifier("retry-statement-cleanup")
            case .committing, .saved:
                Button {
                } label: {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Finishing…")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.prominentAction)
                .disabled(true)
                .accessibilityIdentifier("statement-import-finishing")
            case .reviewing, .failed:
                Button {
                    commitConfirmation = review.commitConfirmation
                } label: {
                    Label(
                        primaryCommitTitle(review.commitConfirmation),
                        systemImage: primaryCommitSystemImage(review.commitConfirmation)
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.prominentAction)
                .disabled(review.commitConfirmation == nil)
                .accessibilityIdentifier("request-statement-import")
            }
        }
        .frame(maxWidth: MonMonTheme.maxContentWidth)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private var vndAccounts: [CashAccount] {
        accounts.filter {
            $0.currencyCode == VNDCurrency.code && $0.id != AccountSeed.unassignedID
        }
    }

    private func rowStatus(_ row: ReconciledImportRow, review: StatementImportReview) -> RowStatus {
        if let issue = review.validationIssue(for: row) {
            let title: LocalizedStringKey
            switch issue {
            case .account: title = "Not selected: choose a VND account"
            case .source: title = "Not selected: invalid statement reference"
            case .amount: title = "Not selected: amount must be greater than zero"
            case .category: title = "Not selected: choose a valid category"
            case .allocation:
                title = "Cannot import income: fix budget jar allocations and reopen this report"
            }
            return RowStatus(
                title: title, systemImage: "exclamationmark.circle.fill",
                tint: MonMonTheme.danger)
        }
        if row.disposition.isExact {
            return RowStatus(
                title: "Already imported",
                systemImage: "checkmark.seal.fill",
                tint: MonMonTheme.gain
            )
        }
        if !row.isSelected {
            return RowStatus(
                title: "Not selected", systemImage: "minus.circle", tint: MonMonTheme.textSecondary)
        }
        switch row.resolution {
        case .transaction:
            return RowStatus(
                title: "Will be imported",
                systemImage: "plus.circle.fill",
                tint: MonMonTheme.bank
            )
        case .newTransfer, .linkTransaction, .linkTransfer:
            return RowStatus(
                title: "Needs attention", systemImage: "exclamationmark.circle.fill",
                tint: MonMonTheme.danger)
        case .skip:
            return RowStatus(
                title: "Skipped",
                systemImage: "forward.end.circle.fill",
                tint: MonMonTheme.textSecondary
            )
        case .alreadyImported:
            return RowStatus(
                title: "Already imported",
                systemImage: "checkmark.seal.fill",
                tint: MonMonTheme.gain
            )
        case .unresolved:
            return RowStatus(
                title: "Choose category", systemImage: "exclamationmark.circle.fill",
                tint: MonMonTheme.danger)
        }
    }

    private var isReviewCommitting: Bool {
        guard let review, case .committing = review.phase else { return false }
        return true
    }

    private var isCommitConfirmationPresented: Binding<Bool> {
        Binding(
            get: { commitConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    commitConfirmation = nil
                }
            }
        )
    }

    private var commitConfirmationTitle: LocalizedStringKey {
        if commitConfirmation?.removesReviewedStatement == true {
            return "Remove reviewed statement?"
        }
        return "Confirm statement import"
    }

    private func primaryCommitTitle(
        _ confirmation: StatementImportCommitConfirmation?
    ) -> LocalizedStringKey {
        guard let confirmation else { return "Import selected transactions" }
        if confirmation.removesReviewedStatement {
            return "Remove reviewed statement"
        }
        if confirmation.recordCount == 0 {
            return "Finish review"
        }
        return "Import \(confirmation.recordCount) transactions"
    }

    private func commitActionTitle(
        _ confirmation: StatementImportCommitConfirmation
    ) -> LocalizedStringKey {
        confirmation.recordCount == 0
            ? "Finish review"
            : "Import \(confirmation.recordCount) transactions"
    }

    private func primaryCommitSystemImage(
        _ confirmation: StatementImportCommitConfirmation?
    ) -> String {
        guard let confirmation else { return "square.and.arrow.down" }
        if confirmation.removesReviewedStatement {
            return "trash"
        }
        return confirmation.recordCount == 0 ? "checkmark.circle" : "square.and.arrow.down"
    }

    private func confirmationCounts(
        _ confirmation: StatementImportCommitConfirmation
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("New transactions: \(confirmation.summary.newTransactionCount)")
            Text("Skipped: \(confirmation.summary.skippedCount)")
            if confirmation.summary.alreadyImportedCount > 0 {
                Text("Already imported: \(confirmation.summary.alreadyImportedCount)")
            }
        }
    }

    private func commitBlocker(_ review: StatementImportReview) -> LocalizedStringKey? {
        switch review.phase {
        case .committing, .saved, .cleanupNeeded:
            return nil
        case .reviewing, .failed:
            break
        }
        if !review.statement.isComplete {
            return "Resolve statement issues before importing."
        }
        if review.statementAccountID == nil {
            return "Choose the statement account to continue."
        }
        if review.selectedCount == 0 && !review.rows.allSatisfy(\.disposition.isExact) {
            return "Select at least one transaction to import."
        }
        if review.summary.unresolvedCount == 1 {
            return "1 transaction needs attention."
        }
        if review.summary.unresolvedCount > 1 {
            return "\(review.summary.unresolvedCount) transactions need attention."
        }
        if review.commitConfirmation == nil {
            return "Review invalid selections before importing."
        }
        return nil
    }

    private func reviewFailureMessage(
        _ failure: StatementImportReviewFailure
    ) -> LocalizedStringKey {
        switch failure {
        case .invalidRows(let count):
            "\(count) transactions could not be imported and were unchecked. See Needs attention below. You can import the remaining selected transactions."
        case .accountUnavailable:
            "The selected account is no longer available. Choose a VND account and select the transactions to import."
        case .invalidReview:
            "This report could not be validated. Close it and reopen it from the import inbox."
        case .staleReview:
            "Your records changed while saving. Close this report and reopen it to refresh the imported transactions."
        case .storeFailure:
            "MonMon could not write to its data store. This does not mean a transaction is invalid. Try importing again."
        case .unknown:
            "MonMon could not finish this import. Try again, or close this report and reopen it."
        }
    }

    private func confirmCommit(_ review: StatementImportReview) {
        commitConfirmation = nil
        Task {
            await review.commit()
            await finishSavedReview(review)
        }
    }

    private func retryCleanup(_ review: StatementImportReview) {
        Task {
            await review.retryCleanup()
            await finishSavedReview(review)
        }
    }

    private func finishSavedReview(_ review: StatementImportReview) async {
        guard case .saved(let report) = review.phase else { return }
        await inbox.completeReview(staged, report: report)
        dismiss()
    }

    private func prepareReview(_ preview: StatementImportPreview) {
        guard review?.staged != preview.staged || review?.statement != preview.statement else {
            return
        }
        let snapshot = StatementImportReviewSnapshot(
            accounts: vndAccounts.map {
                StatementImportAccountSnapshot(id: $0.id, currencyCode: $0.currencyCode)
            },
            categories: categories.map {
                StatementImportCategorySnapshot(id: $0.id, kind: $0.kind)
            },
            transactions: transactions.map {
                StatementImportTransactionSnapshot(
                    id: $0.id,
                    kind: $0.kind,
                    amount: $0.amount,
                    occurredAt: $0.occurredAt,
                    note: $0.note,
                    accountID: $0.accountID,
                    currencyCode: $0.currencyCode,
                    sourceImportID: $0.sourceImportID
                )
            },
            transfers: transfers.map {
                StatementImportTransferSnapshot(
                    id: $0.id,
                    amount: $0.amount,
                    occurredAt: $0.occurredAt,
                    sourceAccountID: $0.sourceAccountID,
                    destinationAccountID: $0.destinationAccountID,
                    currencyCode: $0.currencyCode,
                    sourceAccountImportID: $0.sourceAccountImportID,
                    destinationAccountImportID: $0.destinationAccountImportID,
                    note: $0.note
                )
            },
            defaults: StatementImportCategoryDefaults(
                expenseCategoryID: TransactionDefaults.resolveCategoryID(
                    defaultExpenseCategoryValue,
                    categories: categories,
                    kind: .expense
                ),
                incomeCategoryID: TransactionDefaults.resolveCategoryID(
                    defaultIncomeCategoryValue,
                    categories: categories,
                    kind: .income
                )
            ),
            defaultAccountID: TransactionDefaults.resolveAccountID(
                defaultAccountValue,
                accounts: vndAccounts
            )
        )
        let mapping = StatementAccountMapping(defaults: .standard)
        let inboxService = try? StatementImportInboxService.live()
        let commitService = StatementImportCommitService(container: modelContext.container)
        review = StatementImportReview(
            preview: preview,
            snapshot: snapshot,
            accountMapping: mapping,
            complete: { request, staged in
                guard let inboxService else {
                    throw StatementImportCommitError.storeFailure
                }
                return try inboxService.completeImport(
                    request,
                    staged: staged,
                    commitService: commitService,
                    accountMapping: mapping
                )
            },
            retryCleanup: { staged in
                inboxService?.retryCleanup(staged) ?? false
            }
        )
    }

    private func issueMessage(_ issue: BankStatementIssue) -> LocalizedStringKey {
        switch issue {
        case .ambiguousAmount(let page, let row):
            "Page \(page), row \(row): amount direction is ambiguous."
        case .invalidRow(let page, let row):
            "Page \(page), row \(row): transaction data is invalid."
        case .totalsMismatch:
            "Parsed totals do not match the totals printed by the bank."
        }
    }

    private func bankName(_ bank: BankStatementBank) -> String {
        switch bank {
        case .tpBank:
            "TPBank"
        }
    }

    private func period(_ range: ClosedRange<Date>) -> String {
        let format = dateFormat.style
        return "\(range.lowerBound.formatted(format)) – \(range.upperBound.formatted(format))"
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
    }

    private func removeStatement() {
        isRemoving = true
        Task {
            let removed = await inbox.remove(staged)
            isRemoving = false
            if removed {
                dismiss()
            }
        }
    }

    private struct RowEditorSelection: Identifiable {
        let id: String
    }

    private struct RowStatus {
        let title: LocalizedStringKey
        let systemImage: String
        let tint: Color
    }
}

private extension View {
    func importReviewListRow(top: CGFloat, bottom: CGFloat) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
