import SwiftUI

struct StatementImportRowEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Bindable var review: StatementImportReview
    let rowIndex: Int
    let accounts: [CashAccount]
    let categories: [TransactionCategory]
    let transactions: [MoneyTransaction]
    let transfers: [AccountTransfer]

    @State private var choice: Choice?
    @State private var categoryID: UUID?
    @State private var otherAccountID: UUID?
    @State private var note: String

    init(
        review: StatementImportReview,
        rowIndex: Int,
        accounts: [CashAccount],
        categories: [TransactionCategory],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer]
    ) {
        self.review = review
        self.rowIndex = rowIndex
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.transfers = transfers

        let resolution = review.rows[rowIndex].resolution
        _choice = State(initialValue: Self.choice(for: resolution))
        switch resolution {
        case let .transaction(categoryID, note):
            _categoryID = State(initialValue: categoryID)
            _otherAccountID = State(initialValue: nil)
            _note = State(initialValue: note)
        case let .newTransfer(otherAccountID, note):
            _categoryID = State(initialValue: nil)
            _otherAccountID = State(initialValue: otherAccountID)
            _note = State(initialValue: note)
        default:
            _categoryID = State(initialValue: nil)
            _otherAccountID = State(initialValue: nil)
            _note = State(initialValue: review.rows[rowIndex].candidate.note)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                sourceSection

                if row.disposition.isExact {
                    Section {
                        Label("Already imported", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(MonMonTheme.gain)
                            .accessibilityIdentifier("import-row-status")
                    }
                } else {
                    actionSection
                    configurationSection
                }
            }
            .compactRootNavigationTitle("Resolve transaction")
            .toolbar {
                if row.disposition.isExact {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { save() }
                            .disabled(!canSave)
                            .accessibilityIdentifier("save-import-row-resolution")
                    }
                }
            }
        }
        .accessibilityIdentifier("import-row-editor")
    }

    private var row: ReconciledImportRow {
        review.rows[rowIndex]
    }

    private var sourceSection: some View {
        Section("Source details") {
            LabeledContent(row.candidate.kind.displayName) {
                Text("\(row.candidate.kind.signLabel)\(VNDCurrency.format(row.candidate.amount))")
                    .monospacedDigit()
            }
            LabeledContent("Date") {
                Text(row.candidate.occurredAt.formatted(dateFormat))
            }
            LabeledContent("Description") {
                Text(
                    row.candidate.note.isEmpty
                        ? String(localized: "No description") : row.candidate.note
                )
                .multilineTextAlignment(.trailing)
            }
            LabeledContent("Reference") {
                Text(row.candidate.sourceReference)
                    .textSelection(.enabled)
            }
            LabeledContent("Page") {
                Text(row.candidate.sourcePage.formatted())
            }
        }
    }

    private var actionSection: some View {
        Section("Action") {
            choiceButton(
                .transaction,
                title: "Create transaction",
                systemImage: "plus.circle",
                accessibilityIdentifier: "create-import-transaction"
            )
            choiceButton(
                .transfer,
                title: "Create transfer",
                systemImage: "arrow.left.arrow.right",
                accessibilityIdentifier: "create-import-transfer"
            )

            ForEach(Array(possibleTransactionIDs.enumerated()), id: \.element) { index, id in
                if let transaction = transactions.first(where: { $0.id == id }) {
                    choiceButton(
                        .transactionLink(id),
                        title: "Link existing transaction",
                        detail: existingTransactionDetail(transaction),
                        systemImage: "link",
                        accessibilityIdentifier: "link-import-transaction-\(index)"
                    )
                }
            }

            ForEach(Array(possibleTransferIDs.enumerated()), id: \.element) { index, id in
                if let transfer = transfers.first(where: { $0.id == id }) {
                    choiceButton(
                        .transferLink(id),
                        title: "Link existing transfer",
                        detail: existingTransferDetail(transfer),
                        systemImage: "link",
                        accessibilityIdentifier: "link-import-transfer-\(index)"
                    )
                }
            }

            choiceButton(
                .skip,
                title: "Skip this row",
                systemImage: "forward.end",
                accessibilityIdentifier: "skip-import-row"
            )
        }
    }

    @ViewBuilder
    private var configurationSection: some View {
        switch choice {
        case .transaction:
            Section("Transaction") {
                Picker("Category", selection: $categoryID) {
                    Text("Choose").tag(nil as UUID?)
                    ForEach(matchingCategories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(2...5)
            }

        case .transfer:
            Section("Transfer") {
                Picker("Other account", selection: $otherAccountID) {
                    Text("Choose").tag(nil as UUID?)
                    ForEach(otherAccounts) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(2...5)
            }

        case .transactionLink, .transferLink:
            Section {
                Text("This statement row will be linked to the existing record.")
                    .font(.footnote)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

        case .skip:
            Section {
                Text("No record will be created. This row can appear again in another statement.")
                    .font(.footnote)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

        case nil:
            Section {
                Label("Choose how to handle this row.", systemImage: "exclamationmark.circle")
                    .foregroundStyle(MonMonTheme.danger)
            }
        }
    }

    private var matchingCategories: [TransactionCategory] {
        categories.filter { $0.kind == row.candidate.kind }
    }

    private var otherAccounts: [CashAccount] {
        accounts.filter {
            $0.currencyCode == VNDCurrency.code && $0.id != AccountSeed.unassignedID
                && $0.id != review.statementAccountID
        }
    }

    private var possibleTransactionIDs: [UUID] {
        guard case let .possibleMatches(transactionIDs, _) = row.disposition else { return [] }
        return transactionIDs
    }

    private var possibleTransferIDs: [UUID] {
        guard case let .possibleMatches(_, transferIDs) = row.disposition else { return [] }
        return transferIDs
    }

    private var canSave: Bool {
        switch choice {
        case .transaction:
            categoryID != nil
        case .transfer:
            otherAccountID != nil
        case .transactionLink, .transferLink, .skip:
            true
        case nil:
            false
        }
    }

    private var dateFormat: Date.FormatStyle {
        Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)
    }

    private func choiceButton(
        _ value: Choice,
        title: LocalizedStringKey,
        detail: String? = nil,
        systemImage: String,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        Button {
            choice = value
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if choice == value {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MonMonTheme.bank)
                        .accessibilityLabel("Selected")
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "import-row-choice")
    }

    private func existingTransactionDetail(_ transaction: MoneyTransaction) -> String {
        transaction.note.isEmpty
            ? transaction.occurredAt.formatted(dateFormat)
            : transaction.note
    }

    private func existingTransferDetail(_ transfer: AccountTransfer) -> String {
        let source = accounts.first { $0.id == transfer.sourceAccountID }?.name ?? ""
        let destination = accounts.first { $0.id == transfer.destinationAccountID }?.name ?? ""
        return "\(source) → \(destination)"
    }

    private func save() {
        guard let choice else { return }
        let resolution: ImportRowResolution
        switch choice {
        case .transaction:
            guard let categoryID else { return }
            resolution = .transaction(categoryID: categoryID, note: note)
        case .transfer:
            guard let otherAccountID else { return }
            resolution = .newTransfer(otherAccountID: otherAccountID, note: note)
        case .transactionLink(let id):
            resolution = .linkTransaction(transactionID: id)
        case .transferLink(let id):
            resolution = .linkTransfer(transferID: id)
        case .skip:
            resolution = .skip
        }
        review.setResolution(resolution, forCandidateID: row.id)
        dismiss()
    }

    private static func choice(for resolution: ImportRowResolution) -> Choice? {
        switch resolution {
        case .transaction:
            .transaction
        case .newTransfer:
            .transfer
        case .linkTransaction(let id):
            .transactionLink(id)
        case .linkTransfer(let id):
            .transferLink(id)
        case .skip:
            .skip
        case .alreadyImported, .unresolved:
            nil
        }
    }

    private enum Choice: Hashable {
        case transaction
        case transfer
        case transactionLink(UUID)
        case transferLink(UUID)
        case skip
    }
}
