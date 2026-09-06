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
    /// The last value this view filled in. While the box still holds it, the
    /// figure is the app's and may be re-derived; once it differs, it is the
    /// owner's and is left alone.
    @State private var autofilledValueText = ""

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
                    // Gross, for the reason `CryptoSwapDraft` documents: a fee
                    // is a cost of trading, not a change in what the trade was
                    // booked at.
                    valueText: VNDCurrency.formatPlain(sale.grossProceeds),
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
                receivedInstrument: receivedInstrument,
                marketImpliedUnitsReceived: marketImpliedUnitsReceived,
                onUseImpliedUnitsReceived: {
                    if let implied = marketImpliedUnitsReceived {
                        draft.unitsReceivedText = UnitQuantity.format(implied)
                    }
                },
                isEditing: mode.editedSale != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                rateStatusMessage: rateLoader.phase.message(in: locale),
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(mode.editedSale == nil ? "Swap coins" : "Edit swap")
            .task { fillFromStore() }
            // The value follows what was given up. It is re-derived while the
            // box still holds what this view put there, and left alone the
            // moment the owner types over it — a figure somebody corrected must
            // not be quietly replaced by the next keystroke elsewhere.
            .onChange(of: valueInputs) { _, _ in refillValue() }
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

    private var receivedInstrument: FundInstrument? {
        guard let id = draft.receivedInstrumentID else {
            return nil
        }
        return instruments.first { $0.id == id }
    }

    /// What the given units are worth at today's published price.
    ///
    /// Taken from the coin given up rather than the one received, because that
    /// is what the trade cost: whatever the owner got for it, they gave this
    /// much away. A trade done under the published price then shows as an
    /// unrealized loss on the new position, which is what paying a spread is.
    private var marketValueGiven: Decimal? {
        guard let price = givenInstrument?.currentPricePerUnit, price > 0,
            let units = UnitQuantity.parse(draft.unitsGivenText), units > 0
        else {
            return nil
        }
        return FundValuation.marketValue(units: units, pricePerUnit: price)
    }

    /// How much of the received coin that value buys at its published price.
    /// Offered as a suggestion only: what was actually received is a fact off
    /// an exchange screen, and a guess in that field would become the position.
    private var marketImpliedUnitsReceived: Decimal? {
        guard let marketValueGiven,
            let price = receivedInstrument?.currentPricePerUnit,
            price > 0
        else {
            return nil
        }
        return marketValueGiven / price
    }

    /// What the derived value depends on. Kept as one value so a single
    /// `onChange` covers every input to it.
    private var valueInputs: String {
        "\(draft.unitsGivenText)|\(draft.valueCurrency.rawValue)|\(draft.exchangeRateText)"
    }

    /// Re-derives the value, unless the owner has typed over it.
    private func refillValue() {
        guard draft.valueText.isEmpty || draft.valueText == autofilledValueText else {
            return
        }
        guard let marketValueGiven else {
            return
        }

        let text: String
        switch draft.valueCurrency {
        case .vnd:
            text = VNDCurrency.formatPlain(marketValueGiven)
        case .usd:
            guard let rate = VNDCurrency.parse(draft.exchangeRateText), rate > 0,
                let dollars = USDPrice.inDollars(marketValueGiven, rate: rate)
            else {
                return
            }
            text = USDPrice.format(dollars)
        }

        draft.valueText = text
        autofilledValueText = text
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

        // The whole lot, because swapping all of it is the common case. The
        // value follows from it through the same path every later change uses.
        draft.unitsGivenText = UnitQuantity.format(displayedRemainingUnits)
        refillValue()
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
