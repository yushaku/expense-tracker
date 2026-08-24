import SwiftData
import SwiftUI

enum FundInstrumentEditorMode: Identifiable {
    case add
    case edit(FundInstrument)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let instrument):
            instrument.id.uuidString
        }
    }

    var editedInstrument: FundInstrument? {
        switch self {
        case .add:
            nil
        case .edit(let instrument):
            instrument
        }
    }
}

/// Adds or edits one catalogue entry. The price is editable here and nowhere
/// else: a position must not be able to change what its instrument is worth.
struct FundInstrumentEditorView: View {
    let mode: FundInstrumentEditorMode
    let kinds: [FundInstrumentKind]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @State private var draft: FundInstrumentDraft
    @State private var validationError: FundInstrumentFormError?
    @State private var saveErrorMessage: String?
    @State private var isConfirmingDelete = false

    init(
        mode: FundInstrumentEditorMode,
        kinds: [FundInstrumentKind] = FundInstrumentKind.allCases
    ) {
        self.mode = mode
        self.kinds = kinds.isEmpty ? FundInstrumentKind.allCases : kinds

        switch mode {
        case .add:
            _draft = State(
                initialValue: FundInstrumentDraft(kind: self.kinds[0], priceAsOf: .now)
            )
        case .edit(let instrument):
            _draft = State(initialValue: FundInstrumentDraft(instrument: instrument))
        }
    }

    var body: some View {
        #if os(macOS)
            form.frame(minWidth: 460, minHeight: 560)
        #else
            form
        #endif
    }

    private var form: some View {
        NavigationStack {
            FundInstrumentEditorForm(
                draft: $draft,
                kinds: kinds,
                isEditing: mode.editedInstrument != nil,
                heldCount: heldCount,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(mode.editedInstrument == nil ? "Add instrument" : "Edit instrument")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-instrument")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier("save-instrument")
                }
            }
            .confirmationDialog(
                "Delete this instrument?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: delete)
                    .accessibilityIdentifier("confirm-delete-instrument")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The price and ticker go with it. Positions are not deleted.")
            }
        }
        .tint(MonMonTheme.accent)
    }

    /// How many positions would be orphaned by deleting this. Deletion is
    /// blocked while it is above zero, matching how an account is guarded while
    /// anything still names it.
    private var heldCount: Int {
        guard let instrument = mode.editedInstrument else {
            return 0
        }
        return FundSummary.holdings(for: instrument, holdings: holdings).count
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        do {
            if let instrument = mode.editedInstrument {
                try draft.apply(to: instrument, existing: instruments)
            } else {
                let instrument = try draft.makeInstrument(
                    id: UUID(),
                    createdAt: .now,
                    existing: instruments
                )
                modelContext.insert(instrument)
            }
        } catch let error as FundInstrumentFormError {
            validationError = error
            return
        } catch {
            saveErrorMessage = "Something went wrong. Try again."
            return
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t save this instrument. Try again."
        }
    }

    private func delete() {
        guard let instrument = mode.editedInstrument, heldCount == 0 else {
            return
        }

        modelContext.delete(instrument)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this instrument. Try again."
        }
    }
}
