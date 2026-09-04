import SwiftData
import SwiftUI

/// Which sale the sheet is about.
///
/// `closeGroup` exists because closing a DCA stack one lot at a time is the
/// same decision typed twenty times. It writes one `FundSale` per open lot, all
/// at one price, one date and one account, so each lot still records what it
/// personally made.
enum FundSaleEditorMode: Identifiable {
    case sell(FundHolding)
    case edit(FundSale)
    case closeGroup(instrumentID: UUID?)

    var id: String {
        switch self {
        case .sell(let holding):
            "sell-\(holding.id.uuidString)"
        case .edit(let sale):
            sale.id.uuidString
        case .closeGroup(let instrumentID):
            "close-\(instrumentID?.uuidString ?? "unmatched")"
        }
    }

    var editedSale: FundSale? {
        switch self {
        case .edit(let sale):
            sale
        default:
            nil
        }
    }

    var isClosingGroup: Bool {
        switch self {
        case .closeGroup:
            true
        default:
            false
        }
    }
}

struct FundSaleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Query(sort: \FundSale.soldAt, order: .reverse)
    private var sales: [FundSale]

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    /// The account the owner told the app to reach for. Shared with the
    /// transaction and recurring editors rather than given a preference of its
    /// own: one answer to "which account, normally" is enough, and a second one
    /// would only be a second thing to keep in step.
    @AppStorage(TransactionDefaults.accountStorageKey)
    private var defaultAccountValue = ""

    private let mode: FundSaleEditorMode

    @Environment(\.locale) private var locale

    @State private var draft: FundSaleDraft
    @State private var validationError: FundSaleFormError?
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var isConfirmingDelete = false
    @State private var rateLoader = USDExchangeRateLoader()

    init(mode: FundSaleEditorMode, defaultDate: Date = .now) {
        self.mode = mode

        switch mode {
        case .edit(let sale):
            _draft = State(initialValue: FundSaleDraft(sale: sale))
        case .sell, .closeGroup:
            _draft = State(initialValue: FundSaleDraft(soldAt: defaultDate))
        }
    }

    var body: some View {
        #if os(macOS)
            form
                .frame(minWidth: 460, minHeight: 680)
        #else
            form
        #endif
    }

    private var form: some View {
        NavigationStack {
            FundSaleEditorForm(
                draft: $draft,
                instrument: instrument,
                remainingUnits: displayedRemainingUnits,
                averageCostPerUnit: averageCostPerUnit,
                accounts: accounts,
                policy: instrumentPolicy,
                isClosingGroup: mode.isClosingGroup,
                isEditing: mode.editedSale != nil,
                validationError: validationError,
                saveErrorMessage: saveErrorMessage,
                rateStatusMessage: rateLoader.phase.message(in: locale),
                onSellEverything: {
                    draft.unitsText = UnitQuantity.format(displayedRemainingUnits)
                },
                onDelete: { isConfirmingDelete = true }
            )
            .navigationTitle(navigationTitle)
            // See `FundEditorView.convertCost(from:to:)` for why this is an
            // `onChange` and not a `task(id:)`.
            .onChange(of: draft.priceCurrency) { previous, current in
                Task { await convertPrice(from: previous, to: current) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancel-fund-sale")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("save-fund-sale")
                }
            }
            .confirmationDialog(
                "Delete this sale?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-fund-sale")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The units return to the position and the proceeds leave the account.")
            }
            .task {
                fillPriceFromCatalogue()
                fillProceedsAccount()
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    /// The lot this sale belongs to, re-read from the store rather than carried,
    /// so editing the position behind the sheet does not leave a stale copy
    /// here. `nil` while closing a whole group, which belongs to no single lot.
    private var holding: FundHolding? {
        switch mode {
        case .sell(let holding):
            return holding
        case .edit(let sale):
            return holdings.first { $0.id == sale.holdingID }
        case .closeGroup:
            return nil
        }
    }

    /// The lots this sheet can sell out of: one, or every open lot in the fund.
    private var targetHoldings: [FundHolding] {
        switch mode {
        case .sell, .edit:
            return holding.map { [$0] } ?? []
        case .closeGroup(let instrumentID):
            return
                holdings
                .filter { $0.instrumentID == instrumentID }
                .filter { $0.remainingUnits(sales: sales) > 0 }
                .sorted { $0.boughtOn < $1.boughtOn }
        }
    }

    private var instrument: FundInstrument? {
        switch mode {
        case .closeGroup(let instrumentID):
            return instrumentID.flatMap { id in instruments.first { $0.id == id } }
        default:
            return holding.flatMap { instruments.matching($0) }
        }
    }

    private var instrumentPolicy: FundInstrumentPolicy {
        instrument?.kind.policy ?? FundInstrumentKind.fund.policy
    }

    /// What is still held, in stored units.
    ///
    /// The edited sale's own units are added back, so re-saving unchanged values
    /// is never reported as overselling — the same add-back
    /// `FundEditorView.availableBalance(for:)` makes against a cost basis.
    private var remainingUnits: Decimal {
        var remaining = targetHoldings.reduce(Decimal.zero) { total, holding in
            total + holding.remainingUnits(sales: sales)
        }

        if let editedSale = mode.editedSale {
            remaining += editedSale.units
        }

        return remaining
    }

    /// The same figure in the unit the owner types: chỉ for gold.
    private var displayedRemainingUnits: Decimal {
        instrumentPolicy.quantity.displayedUnits(fromStored: remainingUnits)
    }

    /// What the units on offer cost, weighted across the lots being sold. Zero
    /// when there is nothing left, which the form reads as "no comparison to
    /// draw" rather than as a free position.
    private var averageCostPerUnit: Decimal {
        let units = targetHoldings.reduce(Decimal.zero) { total, holding in
            total + holding.remainingUnits(sales: sales)
        }

        guard units > 0 else {
            return holding?.averageCostPerUnit ?? .zero
        }

        let cost = targetHoldings.reduce(Decimal.zero) { total, holding in
            total + holding.remainingCostBasis(sales: sales)
        }

        return cost / units
    }

    private var navigationTitle: LocalizedStringKey {
        if mode.editedSale != nil {
            return "Edit sale"
        }

        return mode.isClosingGroup ? "Close position" : "Sell"
    }

    /// Keeps the amount the same when the currency under it changes, so the
    /// catalogue price filled in below can be read in dollars without becoming
    /// a different number. Mirrors `FundEditorView.convertCost(from:to:)`.
    private func convertPrice(
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
            guard let dong = VNDCurrency.parse(draft.pricePerUnitText),
                let dollars = USDPrice.inDollars(dong, rate: rate)
            else {
                return
            }
            draft.pricePerUnitText = USDPrice.format(dollars)

        case .vnd:
            guard let dollars = USDPrice.parse(draft.pricePerUnitText),
                let dong = USDPrice.inDong(dollars, rate: rate)
            else {
                return
            }
            draft.pricePerUnitText = VNDCurrency.formatPlain(dong)
        }
    }

    /// Offers today's price rather than making the owner retype it. Only ever
    /// fills an empty field, so it cannot overwrite what the owner typed, and it
    /// never touches a sale being edited — that one already has the price it was
    /// sold at.
    private func fillPriceFromCatalogue() {
        guard mode.editedSale == nil,
            draft.pricePerUnitText.isEmpty,
            let instrument,
            instrument.currentPricePerUnit > 0
        else {
            return
        }

        draft.pricePerUnitText = VNDCurrency.formatPlain(instrument.currentPricePerUnit)
    }

    /// Offers the default account rather than opening on "Choose". Only ever
    /// fills an empty field and never touches a sale being edited, for the same
    /// reason the price fill does not: that one already went somewhere.
    private func fillProceedsAccount() {
        guard mode.editedSale == nil, draft.proceedsAccountID == nil else {
            return
        }

        draft.proceedsAccountID = TransactionDefaults.resolveAccountID(
            defaultAccountValue,
            accounts: accounts
        )
    }

    /// The draft in stored units. Gold is typed in chỉ and kept in lượng, so the
    /// conversion happens once, here, on its way to validation — the same place
    /// `FundEditorView.draftForSaving` does it.
    private var draftForSaving: FundSaleDraft {
        var converted = draft

        if mode.isClosingGroup {
            // There is no quantity field to read: closing sells everything on
            // offer. Filling it in keeps one validation path for both shapes of
            // sale rather than a second one that could drift from it.
            converted.unitsText = NSDecimalNumber(decimal: remainingUnits).stringValue
            return converted
        }

        guard let units = instrumentPolicy.quantity.storedUnits(fromEntryText: draft.unitsText)
        else {
            return converted
        }

        converted.unitsText = NSDecimalNumber(decimal: units).stringValue
        return converted
    }

    private func save() {
        validationError = nil
        saveErrorMessage = nil

        let savingDraft = draftForSaving

        do {
            let values = try savingDraft.validate(remainingUnits: remainingUnits)

            if let editedSale = mode.editedSale {
                try savingDraft.apply(to: editedSale, remainingUnits: remainingUnits)
            } else if mode.isClosingGroup {
                try closeEveryOpenLot(values)
            } else {
                guard let holding else {
                    throw FundSaleFormError.exceedsRemainingUnits
                }

                let sale = try savingDraft.makeSale(
                    id: UUID(),
                    holdingID: holding.id,
                    createdAt: .now,
                    remainingUnits: remainingUnits
                )
                modelContext.insert(sale)
            }
        } catch let error as FundSaleFormError {
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
            saveErrorMessage = "Couldn’t save this sale. Try again."
        }
    }

    /// One sale per open lot, each for exactly what that lot has left.
    ///
    /// Written per lot rather than as one record against the fund, because the
    /// cost a sale is measured against lives on the lot: a single record would
    /// have to pick one lot's average cost and misreport every other.
    private func closeEveryOpenLot(_ values: FundSaleDraft.ValidatedValues) throws {
        let lots = targetHoldings
        guard !lots.isEmpty else {
            throw FundSaleFormError.exceedsRemainingUnits
        }

        // Weighted by what each lot sells for rather than by its unit count,
        // so the split also knows how much fee each lot can carry.
        let grossProceeds = lots.map { lot in
            FundValuation.marketValue(
                units: lot.remainingUnits(sales: sales),
                pricePerUnit: values.pricePerUnit
            )
        }
        let allocatedFees = FundSaleSummary.allocateFee(
            values.fee,
            grossProceeds: grossProceeds
        )

        for (index, lot) in lots.enumerated() {
            let units = lot.remainingUnits(sales: sales)
            guard units > 0 else {
                continue
            }

            modelContext.insert(
                FundSale(
                    id: UUID(),
                    holdingID: lot.id,
                    units: units,
                    pricePerUnit: values.pricePerUnit,
                    fee: allocatedFees[index],
                    proceedsAccountID: values.proceedsAccountID,
                    soldAt: values.soldAt,
                    note: values.note,
                    currencyCode: VNDCurrency.code,
                    exchangeRate: values.exchangeRate,
                    createdAt: .now
                )
            )
        }
    }

    private func delete() {
        guard let editedSale = mode.editedSale else {
            return
        }

        saveErrorMessage = nil
        modelContext.delete(editedSale)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t delete this sale. Try again."
        }
    }
}
