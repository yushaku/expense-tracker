import SwiftData
import SwiftUI

enum DebtPaymentEditorMode: Identifiable {
    case add(Debt)
    case edit(DebtPayment)

    var id: String {
        switch self {
        case .add(let debt):
            "add-\(debt.id.uuidString)"
        case .edit(let payment):
            payment.id.uuidString
        }
    }

    var editedPayment: DebtPayment? {
        switch self {
        case .add:
            nil
        case .edit(let payment):
            payment
        }
    }
}

struct DebtPaymentEditorView: View {
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

    private let mode: DebtPaymentEditorMode
    private let debt: Debt

    @State private var draft: DebtPaymentDraft
    @State private var validationError: DebtPaymentFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false

    init(mode: DebtPaymentEditorMode, debt: Debt, defaultDate: Date = .now) {
        self.mode = mode
        self.debt = debt

        switch mode {
        case .add:
            // Most payments go back the way the money came.
            _draft = State(
                initialValue: DebtPaymentDraft(
                    occurredAt: defaultDate,
                    accountID: debt.accountID
                )
            )
        case .edit(let payment):
            _draft = State(initialValue: DebtPaymentDraft(payment: payment))
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
            DebtPaymentEditorForm(
                draft: $draft,
                debt: debt,
                outstanding: outstanding,
                accounts: accounts,
                isEditing: mode.editedPayment != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onFillOutstanding: { draft.amountText = VNDCurrency.formatPlain(outstanding) },
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(mode.editedPayment == nil ? "Record payment" : "Edit payment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancel-debt-payment")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("save-debt-payment")
                }
            }
            .confirmationDialog(
                "Delete this payment?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-debt-payment")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The account balance and what is outstanding both return to what they were.")
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    /// What is still owed, with the edited payment's own amount added back so
    /// re-saving an unchanged amount is never reported as an overpayment.
    private var outstanding: Decimal {
        var remaining = DebtSummary.outstanding(for: debt, payments: payments)

        if let editedPayment = mode.editedPayment {
            remaining += editedPayment.amount
        }

        return remaining
    }

    private var sourceAccount: CashAccount? {
        guard let accountID = draft.accountID else {
            return nil
        }

        return accounts.first { $0.id == accountID }
    }

    /// Only a repayment spends money, and the draft ignores this figure when
    /// being repaid. The edited payment's own **signed** amount is removed
    /// rather than added, for the same reason the debt editor does it: the sign
    /// belongs to the parent debt, not to the payment.
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

        if let editedPayment = mode.editedPayment,
            editedPayment.accountID == sourceAccount.id
        {
            available -= editedPayment.signedAmount(for: debt.direction)
        }

        return available
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        let sourceBalance = availableSourceBalance
        let remaining = outstanding

        do {
            if let editedPayment = mode.editedPayment {
                try draft.apply(
                    to: editedPayment,
                    direction: debt.direction,
                    outstanding: remaining,
                    availableSourceBalance: sourceBalance
                )
            } else {
                let payment = try draft.makePayment(
                    id: UUID(),
                    debtID: debt.id,
                    createdAt: .now,
                    direction: debt.direction,
                    outstanding: remaining,
                    availableSourceBalance: sourceBalance
                )
                modelContext.insert(payment)
            }
        } catch let error as DebtPaymentFormError {
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
            saveErrorMessage = "Couldn’t save this payment. Try again."
        }
    }

    private func delete() {
        guard let editedPayment = mode.editedPayment else {
            return
        }

        saveErrorMessage = nil
        modelContext.delete(editedPayment)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this payment. Try again."
        }
    }
}
