import SwiftData
import SwiftUI

enum DebtEditorMode: Identifiable {
    case add
    case edit(Debt)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let debt):
            debt.id.uuidString
        }
    }

    var editedDebt: Debt? {
        switch self {
        case .add:
            nil
        case .edit(let debt):
            debt
        }
    }
}

struct DebtEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

    @Query(sort: \Debt.createdAt, order: .forward)
    private var debts: [Debt]

    @Query(sort: \DebtPayment.occurredAt, order: .reverse)
    private var payments: [DebtPayment]

    private let mode: DebtEditorMode

    @State private var draft: DebtDraft
    @State private var validationError: DebtFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false

    init(mode: DebtEditorMode, defaultDate: Date = .now) {
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: DebtDraft(openedAt: defaultDate))
        case .edit(let debt):
            _draft = State(initialValue: DebtDraft(debt: debt))
        }
    }

    var body: some View {
        #if os(macOS)
            form
                .frame(minWidth: 460, minHeight: 620)
        #else
            form
        #endif
    }

    private var form: some View {
        NavigationStack {
            DebtEditorForm(
                draft: $draft,
                accounts: accounts,
                isEditing: mode.editedDebt != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(mode.editedDebt == nil ? "Add debt" : "Edit debt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancel-debt")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("save-debt")
                }
            }
            .confirmationDialog(
                "Delete this debt?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-debt")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deleteMessage)
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    /// A payment has no meaning without its debt, so deleting one takes its
    /// payments with it. The dialog says so before the owner agrees.
    private var deleteMessage: LocalizedStringKey {
        let count = mode.editedDebt.map { DebtSummary.payments(for: $0, payments: payments).count }

        guard let count, count > 0 else {
            return "Any account balance it moved returns to what it was."
        }

        return "Its \(count) payments go with it, and the account balance returns to what it was."
    }

    private var sourceAccount: CashAccount? {
        guard let accountID = draft.accountID else {
            return nil
        }

        return accounts.first { $0.id == accountID }
    }

    /// What the chosen account may hand over. Only lending spends money, and the
    /// draft ignores this figure entirely when borrowing, so it is computed the
    /// same way either way.
    ///
    /// When editing, this debt's own **signed** principal is removed rather than
    /// its amount added back. A transfer always takes money out of its source,
    /// so the existing editors can add. A debt's contribution flips with its
    /// direction, so adding unconditionally would over-credit by twice the
    /// principal the moment the owner flips a borrowed debt to a lent one, and
    /// wave through a loan the account cannot fund.
    private var availableSourceBalance: Decimal? {
        guard let sourceAccount, !sourceAccount.kind.allowsNegativeBalance else {
            return nil
        }

        var available = CashBalanceSummary.available(
            for: sourceAccount,
            deposits: deposits,
            holdings: holdings,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments
        )

        if let editedDebt = mode.editedDebt, editedDebt.accountID == sourceAccount.id {
            available -= editedDebt.signedPrincipal
        }

        return available
    }

    private var alreadyPaid: Decimal {
        guard let editedDebt = mode.editedDebt else {
            return .zero
        }

        return DebtSummary.paid(for: editedDebt, payments: payments)
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        let sourceBalance = availableSourceBalance

        do {
            if let editedDebt = mode.editedDebt {
                try draft.apply(
                    to: editedDebt,
                    availableSourceBalance: sourceBalance,
                    alreadyPaid: alreadyPaid
                )
            } else {
                let debt = try draft.makeDebt(
                    id: UUID(),
                    createdAt: .now,
                    availableSourceBalance: sourceBalance
                )
                modelContext.insert(debt)
            }
        } catch let error as DebtFormError {
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
            saveErrorMessage = "Couldn’t save this debt. Try again."
        }
    }

    /// The cascade is hand-written because the store has no cascade rules. Both
    /// deletions ride on one `save()`, so a failure cannot leave a payment
    /// pointing at a debt that is gone.
    private func delete() {
        guard let editedDebt = mode.editedDebt else {
            return
        }

        saveErrorMessage = nil

        for payment in DebtSummary.payments(for: editedDebt, payments: payments) {
            modelContext.delete(payment)
        }

        modelContext.delete(editedDebt)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this debt. Try again."
        }
    }
}

#if DEBUG
    #Preview("Debt editor · add") {
        DebtEditorView(mode: .add)
            .modelContainer(PreviewData.populated)
    }
#endif
