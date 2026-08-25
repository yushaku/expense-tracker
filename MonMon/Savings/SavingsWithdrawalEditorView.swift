import SwiftData
import SwiftUI

enum SavingsWithdrawalEditorMode: Identifiable {
    case add(SavingsDeposit)
    case edit(SavingsWithdrawal)

    var id: String {
        switch self {
        case .add(let deposit):
            "add-\(deposit.id.uuidString)"
        case .edit(let withdrawal):
            withdrawal.id.uuidString
        }
    }

    var editedWithdrawal: SavingsWithdrawal? {
        guard case .edit(let withdrawal) = self else { return nil }
        return withdrawal
    }
}

struct SavingsWithdrawalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \SavingsWithdrawal.withdrawnAt, order: .reverse)
    private var withdrawals: [SavingsWithdrawal]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @AppStorage(TransactionDefaults.accountStorageKey)
    private var defaultAccountValue = ""

    private let mode: SavingsWithdrawalEditorMode

    @State private var draft: SavingsWithdrawalDraft
    @State private var validationError: SavingsWithdrawalFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false
    @State private var didPrepareDraft = false

    init(mode: SavingsWithdrawalEditorMode, defaultDate: Date = .now) {
        self.mode = mode

        switch mode {
        case .add:
            _draft = State(initialValue: SavingsWithdrawalDraft(withdrawnAt: defaultDate))
        case .edit(let withdrawal):
            _draft = State(initialValue: SavingsWithdrawalDraft(withdrawal: withdrawal))
        }
    }

    var body: some View {
        #if os(macOS)
            content
                .frame(minWidth: 460, minHeight: 680)
        #else
            content
        #endif
    }

    private var content: some View {
        NavigationStack {
            Group {
                if let deposit {
                    SavingsWithdrawalEditorForm(
                        draft: $draft,
                        deposit: deposit,
                        remainingPrincipal: remainingPrincipal,
                        suggestedMaturityAmount: suggestedMaturityAmount,
                        accounts: accounts,
                        isEditing: mode.editedWithdrawal != nil,
                        validationError: validationError,
                        saveErrorMessage: saveErrorMessage,
                        onWithdrawEverything: fillRemainingPrincipal,
                        onUseMaturityEstimate: fillMaturitySettlement,
                        onDelete: { isConfirmingDelete = true }
                    )
                } else {
                    ContentUnavailableView(
                        "Savings book unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("This withdrawal no longer has a savings book.")
                    )
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-savings-withdrawal")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(deposit == nil)
                        .accessibilityIdentifier("save-savings-withdrawal")
                }
            }
            .confirmationDialog(
                "Delete this withdrawal?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { delete() }
                    .accessibilityIdentifier("confirm-delete-savings-withdrawal")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "The principal returns to the savings book and the received amount leaves the account."
                )
            }
            .task { prepareDraftIfNeeded() }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private var deposit: SavingsDeposit? {
        switch mode {
        case .add(let deposit):
            return deposit
        case .edit(let withdrawal):
            guard let depositID = withdrawal.depositID else { return nil }
            return deposits.first { $0.id == depositID }
        }
    }

    private var remainingPrincipal: Decimal {
        guard let deposit else { return 0 }

        var remaining = deposit.remainingPrincipal(withdrawals: withdrawals)
        if let editedWithdrawal = mode.editedWithdrawal {
            remaining += editedWithdrawal.principal
        }
        return remaining
    }

    private var suggestedMaturityAmount: Decimal {
        guard let deposit else { return 0 }
        return remainingPrincipal
            + SavingsInterest.projectedInterest(
                principal: remainingPrincipal,
                annualRatePercent: deposit.annualInterestRate,
                days: deposit.termDayCount
            )
    }

    private var navigationTitle: LocalizedStringKey {
        if mode.editedWithdrawal != nil {
            return "Edit withdrawal"
        }

        guard let deposit else { return "Withdraw savings" }
        return deposit.status(withdrawals: withdrawals, asOf: .now) == .matured
            ? "Settle savings book" : "Withdraw savings"
    }

    private func prepareDraftIfNeeded() {
        guard !didPrepareDraft, mode.editedWithdrawal == nil else { return }
        didPrepareDraft = true

        draft.destinationAccountID = TransactionDefaults.resolveAccountID(
            defaultAccountValue,
            accounts: accounts
        )

        guard let deposit,
            deposit.status(withdrawals: withdrawals, asOf: .now) == .matured
        else {
            return
        }

        fillRemainingPrincipal()
        fillMaturityEstimate()
    }

    private func fillMaturitySettlement() {
        fillRemainingPrincipal()
        fillMaturityEstimate()
    }

    private func fillRemainingPrincipal() {
        draft.principalText = VNDCurrency.formatPlain(remainingPrincipal)
    }

    private func fillMaturityEstimate() {
        draft.amountReceivedText = VNDCurrency.formatPlain(suggestedMaturityAmount)
    }

    private func save() {
        guard let deposit else { return }
        validationError = nil
        saveErrorMessage = nil

        do {
            if let editedWithdrawal = mode.editedWithdrawal {
                try draft.apply(
                    to: editedWithdrawal,
                    remainingPrincipal: remainingPrincipal,
                    openedAt: deposit.openedAt,
                    asOf: .now
                )
            } else {
                modelContext.insert(
                    try draft.makeWithdrawal(
                        id: UUID(),
                        depositID: deposit.id,
                        createdAt: .now,
                        remainingPrincipal: remainingPrincipal,
                        openedAt: deposit.openedAt,
                        asOf: .now
                    )
                )
            }
        } catch let error as SavingsWithdrawalFormError {
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
            saveErrorMessage = "Couldn’t save this withdrawal. Try again."
        }
    }

    private func delete() {
        guard let withdrawal = mode.editedWithdrawal else { return }
        modelContext.delete(withdrawal)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this withdrawal. Try again."
        }
    }
}
