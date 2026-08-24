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

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

    @Query(sort: \Debt.createdAt, order: .forward)
    private var debts: [Debt]

    @Query(sort: \DebtPayment.occurredAt, order: .reverse)
    private var payments: [DebtPayment]

    private let mode: FundEditorMode
    private let kinds: [FundInstrumentKind]
    private let isGold: Bool

    @State private var draft: FundDraft
    @State private var validationError: FundFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false
    @State private var isAddingInstrument = false

    init(mode: FundEditorMode, kinds: [FundInstrumentKind]) {
        self.mode = mode
        self.kinds = kinds
        isGold = kinds == [.gold]

        switch mode {
        case .add:
            _draft = State(initialValue: FundDraft())
        case .edit(let holding):
            var initial = FundDraft(holding: holding)
            if kinds == [.gold] {
                initial.unitsText = GoldWeight.formatChi(luong: holding.units)
            }
            _draft = State(initialValue: initial)
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
                instruments: selectableInstruments,
                isGold: isGold,
                isEditing: mode.editedHolding != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                onAddInstrument: { isAddingInstrument = true },
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(navigationTitle)
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
            .sheet(isPresented: $isAddingInstrument) {
                if isGold {
                    FundCatalogueImportView(
                        title: "Add Gold from vang.today",
                        importer: FundCatalogueImport(provider: VangTodayQuoteProvider())
                    )
                } else {
                    FundInstrumentEditorView(mode: .add)
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
        let savingDraft = draftForSaving

        do {
            if let editedHolding = mode.editedHolding {
                try savingDraft.apply(
                    to: editedHolding,
                    availableSourceBalance: availableSourceBalance
                )
            } else {
                let holding = try savingDraft.makeHolding(
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

    private var selectableInstruments: [FundInstrument] {
        instruments.filter { kinds.contains($0.kind) }
    }

    private var navigationTitle: String {
        if isGold {
            return mode.editedHolding == nil ? "Add gold" : "Edit gold"
        }
        return mode.editedHolding == nil ? "Add holding" : "Edit holding"
    }

    private var draftForSaving: FundDraft {
        guard isGold, let luong = GoldWeight.parseChi(draft.unitsText) else {
            return draft
        }
        var converted = draft
        converted.unitsText = NSDecimalNumber(decimal: luong).stringValue
        return converted
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
        FundEditorView(mode: .add, kinds: [.fund, .etf])
            .modelContainer(PreviewData.populated)
    }
#endif
