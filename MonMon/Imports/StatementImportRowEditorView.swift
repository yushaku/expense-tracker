import SwiftUI

struct StatementImportRowEditorView: View {
    @Environment(\.appDateFormat) private var dateFormat

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Bindable var review: StatementImportReview
    let rowIndex: Int
    let categories: [TransactionCategory]

    @State private var categoryID: UUID?
    @State private var note: String

    init(review: StatementImportReview, rowIndex: Int, categories: [TransactionCategory]) {
        self.review = review
        self.rowIndex = rowIndex
        self.categories = categories

        let row = review.rows[rowIndex]
        if case let .transaction(categoryID, note) = row.resolution {
            _categoryID = State(initialValue: categoryID)
            _note = State(initialValue: note)
        } else {
            _categoryID = State(initialValue: nil)
            _note = State(initialValue: row.candidate.note)
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
                    configurationSection
                }
            }
            .compactRootNavigationTitle("Review transaction")
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
                Text(dateFormat.dateTime(row.candidate.occurredAt, in: locale))
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

    private var configurationSection: some View {
        Section("Create transaction") {
            Picker("Category", selection: $categoryID) {
                Text("Choose").tag(nil as UUID?)
                ForEach(matchingCategories) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            TextField("Note", text: $note, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private var matchingCategories: [TransactionCategory] {
        categories.filter { $0.kind == row.candidate.kind }
    }

    private var canSave: Bool {
        matchingCategories.contains { $0.id == categoryID }
    }

    private func save() {
        guard canSave, let categoryID else { return }
        review.setResolution(
            .transaction(categoryID: categoryID, note: note), forCandidateID: row.id)
        dismiss()
    }
}
