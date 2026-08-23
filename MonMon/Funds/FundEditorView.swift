import SwiftData
import SwiftUI

enum FundEditorMode: Identifiable {
    case add
    case edit(FundHolding)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let holding):
            holding.id.uuidString
        }
    }

    var editedHolding: FundHolding? {
        switch self {
        case .add:
            nil
        case .edit(let holding):
            holding
        }
    }
}

struct FundEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

    @Query(sort: \Debt.createdAt, order: .forward)
    private var debts: [Debt]

    @Query(sort: \DebtPayment.occurredAt, order: .reverse)
    private var payments: [DebtPayment]

    private let mode: FundEditorMode

    @State private var draft: FundDraft
    @State private var validationError: FundFormError?
    @State private var saveErrorMessage: String?
    @State private var isConfirmingDelete = false

    init(mode: FundEditorMode) {
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: FundDraft(navAsOf: .now))
        case .edit(let holding):
            _draft = State(initialValue: FundDraft(holding: holding))
        }
    }

    var body: some View {
        #if os(macOS)
            form
                .frame(minWidth: 460, minHeight: 640)
        #else
            form
        #endif
    }

    private var form: some View {
        NavigationStack {
            FundEditorForm(
                draft: $draft,
                accounts: accounts,
                isEditing: mode.editedHolding != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(mode.editedHolding == nil ? "Add holding" : "Edit holding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancel-fund")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("save-fund")
                }
            }
            .confirmationDialog(
                "Delete this holding?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-fund")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its cost basis returns to the linked account's available balance.")
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private var selectedAccount: CashAccount? {
        guard let sourceAccountID = draft.sourceAccountID else {
            return nil
        }

        return accounts.first { $0.id == sourceAccountID }
    }

    /// Spendable balance the draft may claim. When editing a holding already
    /// funded by this account, its own cost basis is added back so re-saving
    /// unchanged values is not reported as an overdraft.
    private func availableBalance(for account: CashAccount) -> Decimal {
        var available = CashBalanceSummary.available(
            for: account,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments
        )

        if let editedHolding = mode.editedHolding,
            editedHolding.sourceAccountID == account.id
        {
            available += editedHolding.costBasis
        }

        return available
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        let availableSourceBalance = selectedAccount.map(availableBalance(for:))

        do {
            if let editedHolding = mode.editedHolding {
                try draft.apply(
                    to: editedHolding,
                    availableSourceBalance: availableSourceBalance
                )
            } else {
                let holding = try draft.makeHolding(
                    id: UUID(),
                    createdAt: .now,
                    availableSourceBalance: availableSourceBalance
                )
                modelContext.insert(holding)
            }
        } catch let error as FundFormError {
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
            saveErrorMessage = "Couldn’t save this holding. Try again."
        }
    }

    private func delete() {
        guard let editedHolding = mode.editedHolding else {
            return
        }

        saveErrorMessage = nil
        modelContext.delete(editedHolding)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this holding. Try again."
        }
    }
}

#if DEBUG
    #Preview("Fund editor · add") {
        FundEditorView(mode: .add)
            .modelContainer(PreviewData.populated)
    }
#endif
