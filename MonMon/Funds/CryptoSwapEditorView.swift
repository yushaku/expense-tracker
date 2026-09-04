import SwiftData
import SwiftUI

/// Which swap the sheet is about.
enum CryptoSwapEditorMode: Identifiable {
    /// A new swap out of one lot.
    case swap(FundHolding)
    /// One already recorded, named by the sale leg.
    case edit(FundSale)

    var id: String {
        switch self {
        case .swap(let holding):
            "swap-\(holding.id.uuidString)"
        case .edit(let sale):
            "edit-swap-\(sale.id.uuidString)"
        }
    }

    var editedSale: FundSale? {
        switch self {
        case .edit(let sale):
            sale
        case .swap:
            nil
        }
    }
}

/// Exchanging one coin for another, written as both legs in a single save.
///
/// Half a swap is worse than none — a sale with no lot behind it would take
/// units out of the portfolio and put nothing back — so every write here either
/// lands whole or is rolled back.
struct CryptoSwapEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \FundSale.soldAt, order: .reverse)
    private var sales: [FundSale]

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    private let mode: CryptoSwapEditorMode

    @State private var draft: CryptoSwapDraft
    @State private var validationError: CryptoSwapFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false
    @State private var rateLoader = USDExchangeRateLoader()

    init(mode: CryptoSwapEditorMode, defaultDate: Date = .now) {
        self.mode = mode

        switch mode {
        case .swap:
            _draft = State(initialValue: CryptoSwapDraft(swappedAt: defaultDate))
        case .edit(let sale):
            // The received lot is joined in `body`; until the store is to hand
            // the sale alone is all there is to open with.
            _draft = State(
                initialValue: CryptoSwapDraft(
                    unitsGivenText: UnitQuantity.format(sale.units),
                    unitsReceivedText: "",
                    valueText: VNDCurrency.formatPlain(sale.proceeds),
                    swappedAt: sale.soldAt,
                    note: sale.note
                )
            )
        }
    }

    var body: some View {
        #if os(macOS)
            form.frame(minWidth: 460, minHeight: 680)
        #else
            form
        #endif
    }

    private var form: some View {
        NavigationStack {
            CryptoSwapEditorForm(
                draft: $draft,
                givenInstrument: givenInstrument,
                remainingUnits: displayedRemainingUnits,
                receivableInstruments: receivableInstruments,
                isEditing: mode.editedSale != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                rateStatusMessage: rateLoader.phase.message(in: locale),
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(mode.editedSale == nil ? "Swap coins" : "Edit swap")
            .task { fillFromStore() }
            // See `FundEditorView.convertCost(from:to:)` for why this converts
            // rather than leaving a đồng figure to be read as dollars.
            .onChange(of: draft.valueCurrency) { previous, current in
                Task { await convertValue(from: previous, to: current) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-swap")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("save-swap")
                }
            }
            .confirmationDialog(
                "Delete this swap?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Both sides go: the coin you gave comes back into its lot, and the coin you got is removed."
                )
            }
        }
        .tint(MonMonTheme.accent)
    }

    // MARK: - The two legs

    /// The lot being swapped out of.
    private var givenHolding: FundHolding? {
        switch mode {
        case .swap(let holding):
            return holding
        case .edit(let sale):
            return holdings.first { $0.id == sale.holdingID }
        }
    }

    /// The lot a recorded swap bought, when this is an edit.
    private var receivedHolding: FundHolding? {
        guard let sale = mode.editedSale else {
            return nil
        }
        return CryptoSwapDraft.receivedHolding(for: sale, in: holdings)
    }

    private var givenInstrument: FundInstrument? {
        givenHolding.flatMap { instruments.matching($0) }
    }

    /// Every coin in the catalogue but the one being given up.
    private var receivableInstruments: [FundInstrument] {
        instruments.filter { $0.kind == .crypto && $0.id != givenInstrument?.id }
    }

    /// What is still held in the lot, with this swap's own units added back so
    /// re-saving an unchanged swap is never refused.
    private var displayedRemainingUnits: Decimal {
        guard let givenHolding else {
            return .zero
        }

        let remaining = givenHolding.remainingUnits(sales: sales)
        guard let edited = mode.editedSale else {
            return remaining
        }
        return remaining + edited.units
    }

    /// Fills in what only the store knows: the lot a recorded swap bought, and
    /// a starting value for a new one.
    private func fillFromStore() {
        if let received = receivedHolding, let sale = mode.editedSale {
            draft = CryptoSwapDraft(sale: sale, received: received)
            return
        }

        guard mode.editedSale == nil, draft.valueText.isEmpty else {
            return
        }

        // Today's price for the whole lot, so the common case — swapping all of
        // it — needs no arithmetic. Only ever fills an empty field.
        draft.unitsGivenText = UnitQuantity.format(displayedRemainingUnits)
        if let price = givenInstrument?.currentPricePerUnit, price > 0 {
            draft.valueText = VNDCurrency.formatPlain(
                FundValuation.marketValue(units: displayedRemainingUnits, pricePerUnit: price)
            )
        }
    }

    private func convertValue(
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
            guard let dong = VNDCurrency.parse(draft.valueText),
                let dollars = USDPrice.inDollars(dong, rate: rate)
            else {
                return
            }
            draft.valueText = USDPrice.format(dollars)

        case .vnd:
            guard let dollars = USDPrice.parse(draft.valueText),
                let dong = USDPrice.inDong(dollars, rate: rate)
            else {
                return
            }
            draft.valueText = VNDCurrency.formatPlain(dong)
        }
    }

    // MARK: - Writing

    private func save() {
        guard let givenHolding else {
            saveErrorMessage = "This position is no longer here."
            return
        }

        validationError = nil
        saveErrorMessage = nil

        do {
            if let sale = mode.editedSale, let received = receivedHolding {
                try draft.apply(
                    to: sale,
                    received: received,
                    givenHolding: givenHolding,
                    remainingUnits: displayedRemainingUnits
                )
            } else {
                let swap = try draft.makeSwap(
                    givenHolding: givenHolding,
                    remainingUnits: displayedRemainingUnits,
                    createdAt: .now
                )
                // Both, or neither. The save below is what makes it one write.
                modelContext.insert(swap.received)
                modelContext.insert(swap.sale)
            }

            try modelContext.save()
            dismiss()
        } catch let error as CryptoSwapFormError {
            validationError = error
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t save this swap. Try again."
        }
    }

    private func delete() {
        guard let sale = mode.editedSale else {
            return
        }

        // The lot goes with the sale. Leaving it would keep a position the
        // owner never bought with money, funded by a trade that no longer
        // exists.
        if let received = receivedHolding {
            modelContext.delete(received)
        }
        modelContext.delete(sale)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this swap. Try again."
        }
    }
}

#if DEBUG
    #Preview("Swap a coin") {
        CryptoSwapPreview()
            .modelContainer(PreviewData.populated)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }

    private struct CryptoSwapPreview: View {
        @Query(sort: \FundHolding.createdAt, order: .forward)
        private var holdings: [FundHolding]

        var body: some View {
            if let holding = holdings.first {
                CryptoSwapEditorView(mode: .swap(holding))
            } else {
                Text("No position to swap")
            }
        }
    }
#endif
