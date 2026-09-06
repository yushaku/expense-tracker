import Foundation
import Testing

@testable import MonMon

@Suite("Crypto swap draft")
struct CryptoSwapDraftTests {
    private let createdAt = FundTestFactory.referenceDate

    private let bitcoin = FundTestFactory.instrument(
        symbol: "BTC",
        kind: .crypto,
        pricePerUnit: 2_100_000_000
    )
    private let tether = FundTestFactory.instrument(
        symbol: "USDT",
        kind: .crypto,
        pricePerUnit: 26_058
    )

    /// One bitcoin bought at two billion đồng, so a swap at 2.1 billion has a
    /// hundred million of gain in it.
    private func bitcoinLot() -> FundHolding {
        FundTestFactory.holding(
            in: bitcoin,
            units: 1,
            averageCostPerUnit: 2_000_000_000
        )
    }

    private func draft(
        unitsGivenText: String = "1",
        receivedInstrumentID: UUID? = nil,
        unitsReceivedText: String = "80590",
        valueText: String = "2.100.000.000",
        valueCurrency: PriceEntryCurrency = .vnd,
        exchangeRateText: String = ""
    ) -> CryptoSwapDraft {
        CryptoSwapDraft(
            unitsGivenText: unitsGivenText,
            receivedInstrumentID: receivedInstrumentID ?? tether.id,
            unitsReceivedText: unitsReceivedText,
            valueText: valueText,
            valueCurrency: valueCurrency,
            exchangeRateText: exchangeRateText,
            swappedAt: createdAt
        )
    }

    private func error(
        from draft: CryptoSwapDraft,
        remainingUnits: Decimal = 1
    ) -> CryptoSwapFormError? {
        do {
            _ = try draft.validate(
                remainingUnits: remainingUnits,
                givenInstrumentID: bitcoin.id
            )
            return nil
        } catch let error as CryptoSwapFormError {
            return error
        } catch {
            return nil
        }
    }

    // MARK: - The two legs

    @Test("One value settles both legs")
    func oneValueSettlesBothLegs() throws {
        let values = try draft().validate(remainingUnits: 1, givenInstrumentID: bitcoin.id)

        #expect(values.value == 2_100_000_000)
        #expect(values.pricePerUnitGiven == 2_100_000_000)
        // 2.1 billion đồng spread across 80,590 tether.
        #expect(values.costPerUnitReceived == values.value / 80_590)
    }

    @Test("A swap writes a sale of one coin and a lot in the other")
    func swapWritesBothLegs() throws {
        let lot = bitcoinLot()

        let swap = try draft().makeSwap(
            givenHolding: lot,
            remainingUnits: 1,
            createdAt: createdAt
        )

        #expect(swap.sale.holdingID == lot.id)
        #expect(swap.sale.units == 1)
        #expect(swap.sale.pricePerUnit == 2_100_000_000)
        #expect(swap.received.instrumentID == tether.id)
        #expect(swap.received.units == 80_590)
    }

    /// The whole point of the flag: a swap paid into nothing, so no account may
    /// see its value.
    @Test("Neither leg touches a cash account")
    func neitherLegTouchesCash() throws {
        let account = CashAccount(
            id: AccountSeed.unassignedID,
            name: AccountSeed.unassignedName,
            kind: .normal,
            openingBalance: 0,
            currencyCode: VNDCurrency.code,
            createdAt: createdAt
        )

        let swap = try draft().makeSwap(
            givenHolding: bitcoinLot(),
            remainingUnits: 1,
            createdAt: createdAt
        )

        #expect(swap.sale.isSwap)
        #expect(swap.received.sourceAccountID == nil)
        #expect(FundSaleSummary.netFlow(for: account, sales: [swap.sale]) == .zero)
        #expect(FundSaleSummary.count(for: account, sales: [swap.sale]) == 0)
        #expect(
            CashBalanceSummary.fundedAmount(
                for: account,
                deposits: [],
                holdings: [swap.received]
            ) == .zero
        )
    }

    /// The invariant the single value field exists to protect: whatever the
    /// coin given up fetched is exactly what the coin received cost. A swap can
    /// therefore neither create nor destroy value on the way through.
    ///
    /// Market value is a separate question and deliberately not asserted here.
    /// A trade done away from the published price leaves the two legs worth
    /// different amounts, and that difference is real — it is the spread the
    /// owner paid, not an error in the record.
    @Test("What the coin given fetched is what the coin received cost")
    func proceedsEqualTheNewCostBasis() throws {
        let swap = try draft().makeSwap(
            givenHolding: bitcoinLot(),
            remainingUnits: 1,
            createdAt: createdAt
        )

        #expect(swap.sale.proceeds == 2_100_000_000)
        #expect(swap.received.costBasis == swap.sale.proceeds)
    }

    /// A swap done at the published price leaves the portfolio worth what it
    /// was worth a moment earlier.
    @Test("A swap at the market price leaves total assets where they were")
    func swapAtMarketLeavesTotalAssetsAlone() throws {
        let lot = bitcoinLot()
        let catalogue = [bitcoin, tether]
        // 2.1 billion đồng of bitcoin buys exactly this much tether at 26,058.
        let unitsReceived = Decimal(2_100_000_000) / 26_058

        let before = FundSummary.totalMarketValue(
            of: [lot],
            instruments: catalogue,
            sales: []
        )

        let swap = try draft(unitsReceivedText: UnitQuantity.format(unitsReceived))
            .makeSwap(givenHolding: lot, remainingUnits: 1, createdAt: createdAt)

        let after = FundSummary.totalMarketValue(
            of: [lot, swap.received],
            instruments: catalogue,
            sales: [swap.sale]
        )

        // Within the đồng each side rounds to.
        #expect(abs(after - before) <= 1)
    }

    @Test("The coin given up settles its gain")
    func gainOnTheCoinGivenIsSettled() throws {
        let lot = bitcoinLot()

        let swap = try draft().makeSwap(
            givenHolding: lot,
            remainingUnits: 1,
            createdAt: createdAt
        )

        #expect(swap.sale.realizedProfitLoss(costPerUnit: lot.averageCostPerUnit) == 100_000_000)
        #expect(lot.remainingUnits(sales: [swap.sale]) == .zero)
    }

    @Test("The coin received starts at what it was worth, so it has gained nothing yet")
    func coinReceivedStartsFlat() throws {
        let swap = try draft().makeSwap(
            givenHolding: bitcoinLot(),
            remainingUnits: 1,
            createdAt: createdAt
        )

        let profit = swap.received.unrealizedProfitLoss(
            pricePerUnit: swap.received.averageCostPerUnit,
            sales: []
        )
        #expect(profit == .zero)
    }

    // MARK: - Dollars

    @Test("A swap valued in dollars converts once and keeps its rate")
    func dollarValueConvertsOnce() throws {
        let swap = try draft(
            valueText: "80590",
            valueCurrency: .usd,
            exchangeRateText: "26.058"
        )
        .makeSwap(givenHolding: bitcoinLot(), remainingUnits: 1, createdAt: createdAt)

        #expect(swap.sale.pricePerUnit == 2_100_014_220)
        #expect(swap.sale.exchangeRate == 26_058)
        #expect(swap.received.purchaseExchangeRate == 26_058)
    }

    // MARK: - Refusals

    @Test("Swapping more than is still held is refused")
    func oversizedSwapIsRefused() {
        #expect(
            error(from: draft(unitsGivenText: "2"), remainingUnits: 1) == .exceedsRemainingUnits
        )
    }

    @Test("Swapping a coin for itself is refused")
    func sameCoinIsRefused() {
        #expect(error(from: draft(receivedInstrumentID: bitcoin.id)) == .sameInstrument)
    }

    @Test("A swap with no coin chosen is refused")
    func missingReceivedCoinIsRefused() {
        var incomplete = draft()
        incomplete.receivedInstrumentID = nil

        #expect(error(from: incomplete) == .missingReceivedInstrument)
    }

    @Test("Every quantity and value has to be a positive number")
    func quantitiesAndValuesMustBePositive() {
        #expect(error(from: draft(unitsGivenText: "")) == .invalidUnitsGiven)
        #expect(error(from: draft(unitsGivenText: "0")) == .nonPositiveUnitsGiven)
        #expect(error(from: draft(unitsReceivedText: "")) == .invalidUnitsReceived)
        #expect(error(from: draft(unitsReceivedText: "0")) == .nonPositiveUnitsReceived)
        #expect(error(from: draft(valueText: "")) == .invalidValue)
        #expect(error(from: draft(valueText: "0")) == .nonPositiveValue)
    }

    @Test("A dollar value with no rate behind it is refused")
    func dollarValueNeedsARate() {
        #expect(
            error(
                from: draft(valueText: "80590", valueCurrency: .usd, exchangeRateText: "")
            ) == .invalidExchangeRate
        )
        #expect(
            error(
                from: draft(valueText: "80590", valueCurrency: .usd, exchangeRateText: "0")
            ) == .nonPositiveExchangeRate
        )
    }

    // MARK: - Reopening and editing

    @Test("A recorded swap reopens from its two legs")
    func swapReopens() throws {
        let swap = try draft().makeSwap(
            givenHolding: bitcoinLot(),
            remainingUnits: 1,
            createdAt: createdAt
        )

        let reopened = CryptoSwapDraft(sale: swap.sale, received: swap.received)

        #expect(reopened.unitsGivenText == "1")
        #expect(reopened.unitsReceivedText == "80590")
        #expect(reopened.receivedInstrumentID == tether.id)
        #expect(reopened.valueCurrency == .vnd)
        #expect(reopened.valueText == VNDCurrency.formatPlain(2_100_000_000))
    }

    @Test("A swap valued in dollars reopens in dollars")
    func dollarSwapReopensInDollars() throws {
        let swap = try draft(
            valueText: "80590",
            valueCurrency: .usd,
            exchangeRateText: "26.058"
        )
        .makeSwap(givenHolding: bitcoinLot(), remainingUnits: 1, createdAt: createdAt)

        let reopened = CryptoSwapDraft(sale: swap.sale, received: swap.received)

        #expect(reopened.valueCurrency == .usd)
        #expect(reopened.exchangeRateText == VNDCurrency.formatPlain(26_058))
    }

    @Test("Editing rewrites both legs and keeps them pointing at each other")
    func editingRewritesBothLegs() throws {
        let lot = bitcoinLot()
        let swap = try draft().makeSwap(
            givenHolding: lot,
            remainingUnits: 1,
            createdAt: createdAt
        )

        try draft(unitsReceivedText: "80000", valueText: "2.050.000.000")
            .apply(
                to: swap.sale,
                received: swap.received,
                givenHolding: lot,
                remainingUnits: 1
            )

        #expect(swap.received.units == 80_000)
        #expect(swap.sale.pricePerUnit == 2_050_000_000)
        #expect(swap.sale.swapHoldingID == swap.received.id)
    }

    // MARK: - Joining the legs back up

    @Test("Each leg finds the other")
    func legsFindEachOther() throws {
        let swap = try draft().makeSwap(
            givenHolding: bitcoinLot(),
            remainingUnits: 1,
            createdAt: createdAt
        )

        #expect(
            CryptoSwapDraft.receivedHolding(for: swap.sale, in: [swap.received])?.id
                == swap.received.id
        )
        #expect(
            CryptoSwapDraft.swapSale(forHoldingID: swap.received.id, in: [swap.sale])?.id
                == swap.sale.id
        )
    }

    /// A fee is a cost of trading, not a change in what the trade was booked
    /// at. Reopening must therefore show the gross figure, or the value would
    /// shrink on every reopen while the lot it bought kept the gross one.
    @Test("A fee on the sale leg does not shrink the value on reopening")
    func feeDoesNotShrinkTheReopenedValue() throws {
        let swap = try draft().makeSwap(
            givenHolding: bitcoinLot(),
            remainingUnits: 1,
            createdAt: createdAt
        )
        swap.sale.fee = 1_000_000

        let reopened = CryptoSwapDraft(sale: swap.sale, received: swap.received)

        #expect(reopened.valueText == VNDCurrency.formatPlain(2_100_000_000))
        #expect(swap.received.costBasis == swap.sale.grossProceeds)
    }

    @Test("A swap is written without a fee")
    func swapCarriesNoFee() throws {
        let swap = try draft().makeSwap(
            givenHolding: bitcoinLot(),
            remainingUnits: 1,
            createdAt: createdAt
        )

        #expect(swap.sale.fee == .zero)
        #expect(FundInstrumentKind.crypto.policy.fee == nil)
    }

    @Test("An ordinary sale has no other leg to find")
    func ordinarySaleHasNoOtherLeg() {
        let sale = FundTestFactory.sale(
            of: bitcoinLot(),
            units: 1,
            pricePerUnit: 2_100_000_000
        )

        #expect(!sale.isSwap)
        #expect(CryptoSwapDraft.receivedHolding(for: sale, in: []) == nil)
    }
}
