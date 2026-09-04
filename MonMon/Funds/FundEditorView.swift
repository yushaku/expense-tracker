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

    @Query(sort: \SavingsWithdrawal.withdrawnAt, order: .reverse)
    private var withdrawals: [SavingsWithdrawal]

    @Environment(\.locale) private var locale

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \FundSale.soldAt, order: .reverse)
    private var sales: [FundSale]

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
    private let instrumentPolicy: FundInstrumentPolicy

    @State private var draft: FundDraft
    @State private var validationError: FundFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false
    @State private var isAddingInstrument = false
    @State private var rateLoader = USDExchangeRateLoader()
    /// The last average cost this view filled in. While the box still holds it
    /// the figure is the app's and may be replaced; once it differs, it is the
    /// owner's and is left alone.
    @State private var autofilledAverageCostText = ""

    init(mode: FundEditorMode, kinds: [FundInstrumentKind]) {
        self.mode = mode
        self.kinds = kinds
        let policy = (kinds.first ?? .fund).policy
        instrumentPolicy = policy

        switch mode {
        case .add:
            _draft = State(initialValue: FundDraft())
        case .edit(let holding):
            var initial = FundDraft(holding: holding)
            initial.unitsText = UnitQuantity.format(
                policy.quantity.displayedUnits(fromStored: holding.units)
            )
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
                kinds: kinds,
                isEditing: mode.editedHolding != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                rateStatusMessage: rateLoader.phase.message(in: locale),
                onAddInstrument: { isAddingInstrument = true },
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(navigationTitle)
            // `onChange` rather than `task(id:)`: this must run when the owner
            // switches currency, and never on opening. A saved position opens
            // in the currency it was written in, and converting it there would
            // rewrite figures nobody touched.
            .onChange(of: draft.costCurrency) { previous, current in
                Task { await convertCost(from: previous, to: current) }
            }
            // Choosing what you hold fills in what a unit of it costs today.
            // Only on a new position: an existing one already records what was
            // actually paid, and today's price is not that.
            .onChange(of: draft.instrumentID) { _, _ in fillAverageCostFromCatalogue() }
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
            .appSheet(isPresented: $isAddingInstrument) {
                // Gold and coins each have one provider worth importing from,
                // so the sheet goes straight to it. Funds and ETFs have two,
                // and the choice belongs on the catalogue screen rather than
                // half way through entering a position.
                switch instrumentPolicy.editor.catalogueRoute {
                case .goldCatalogue:
                    FundCatalogueImportView(
                        title: "Add Gold from vang.today",
                        importer: FundCatalogueImport(provider: VangTodayQuoteProvider())
                    )
                case .cryptoCatalogue:
                    FundCatalogueImportView(
                        title: "Add from CoinGecko",
                        importer: FundCatalogueImport(provider: CoinGeckoQuoteProvider())
                    )
                case .instrumentEditor:
                    FundInstrumentEditorView(mode: .add, kinds: kinds)
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
                Text(deleteWarning)
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
            withdrawals: withdrawals,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments,
            sales: sales
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

    /// Offers today's buy price rather than making the owner look it up.
    ///
    /// The figure is what a unit would cost to buy now — the shop's asking
    /// price for gold, the published price for anything else — because this
    /// field is a cost basis, not a valuation. It is a starting value: a
    /// purchase made last month went through at a different price, and the
    /// owner types over it.
    ///
    /// Never touches an existing position, and never a figure the owner has
    /// typed.
    private func fillAverageCostFromCatalogue() {
        guard mode.editedHolding == nil else {
            return
        }
        guard
            draft.averageCostText.isEmpty
                || draft.averageCostText == autofilledAverageCostText
        else {
            return
        }
        guard let instrument = selectableInstruments.first(where: { $0.id == draft.instrumentID }),
            instrument.purchasePricePerUnit > 0
        else {
            return
        }

        let price = instrument.purchasePricePerUnit
        let text: String
        switch draft.costCurrency {
        case .vnd:
            text = VNDCurrency.formatPlain(price)
        case .usd:
            guard let rate = VNDCurrency.parse(draft.exchangeRateText), rate > 0,
                let dollars = USDPrice.inDollars(price, rate: rate)
            else {
                return
            }
            text = USDPrice.format(dollars)
        }

        draft.averageCostText = text
        autofilledAverageCostText = text
    }

    /// Keeps the amount the same when the currency under it changes.
    ///
    /// Switching to dollars turns 2.070.646.854 ₫ into $79463 rather than
    /// leaving a đồng figure to be read as dollars, which would overstate a
    /// purchase by four orders of magnitude. The rate is fetched first when the
    /// box is empty — that is the one moment this app has a reason to ask.
    private func convertCost(
        from previous: PriceEntryCurrency,
        to current: PriceEntryCurrency
    ) async {
        guard previous != current else {
            return
        }

        if current == .usd,
            draft.exchangeRateText.trimmingCharacters(in: .whitespaces).isEmpty,
            let fetched = await rateLoader.load()
        {
            draft.exchangeRateText = VNDCurrency.formatPlain(fetched.dongPerDollar)
        }

        guard let rate = VNDCurrency.parse(draft.exchangeRateText), rate > 0 else {
            return
        }

        switch current {
        case .usd:
            guard let dong = VNDCurrency.parse(draft.averageCostText),
                let dollars = USDPrice.inDollars(dong, rate: rate)
            else {
                return
            }
            draft.averageCostText = USDPrice.format(dollars)

        case .vnd:
            guard let dollars = USDPrice.parse(draft.averageCostText),
                let dong = USDPrice.inDong(dollars, rate: rate)
            else {
                return
            }
            draft.averageCostText = VNDCurrency.formatPlain(dong)
        }

        // The converted figure is still the app's if the app put it there.
        if !autofilledAverageCostText.isEmpty {
            autofilledAverageCostText = draft.averageCostText
        }
    }

    private var selectableInstruments: [FundInstrument] {
        instruments.filter { kinds.contains($0.kind) }
    }

    private var navigationTitle: String {
        mode.editedHolding == nil
            ? instrumentPolicy.editor.newTitleKey : instrumentPolicy.editor.editTitleKey
    }

    private var draftForSaving: FundDraft {
        guard let units = instrumentPolicy.quantity.storedUnits(fromEntryText: draft.unitsText)
        else {
            return draft
        }
        var converted = draft
        converted.unitsText = NSDecimalNumber(decimal: units).stringValue
        return converted
    }

    /// Says what else goes. A lot that has been sold out of takes its sales
    /// with it, and those moved money into an account — silently reversing that
    /// would leave a balance the owner could not account for.
    private var deleteWarning: LocalizedStringKey {
        let count = soldRecords.count
        guard count > 0 else {
            return "Its cost basis returns to the linked account's available balance."
        }

        return """
            Its \(count) sales go with it, so their proceeds leave the accounts they \
            landed in and its cost basis returns to the account that funded it.
            """
    }

    /// The sales out of the lot being edited. Deleting a lot deletes them for
    /// the same reason deleting a debt deletes its payments: the cost a sale is
    /// measured against lives on the lot, so an orphan is not untidy, it is
    /// uncomputable.
    private var soldRecords: [FundSale] {
        guard let editedHolding = mode.editedHolding else {
            return []
        }

        return FundSaleSummary.sales(for: editedHolding, sales: sales)
    }

    private func delete() {
        guard let editedHolding = mode.editedHolding else {
            return
        }

        saveErrorMessage = nil

        for sale in soldRecords {
            modelContext.delete(sale)
        }

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
