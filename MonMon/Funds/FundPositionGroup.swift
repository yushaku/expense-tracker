import Foundation

/// Every position held in one instrument, added up.
///
/// Buying the same fund monthly is one decision recorded many times, so the list
/// shows one card per fund rather than one per purchase: the units add up, the
/// cost basis adds up, and the average cost is what the whole stack cost per
/// unit. The individual purchases stay intact behind the card, because that is
/// where the dates and the funding accounts live.
struct FundPositionGroup: Identifiable {
    /// The instrument these positions are held in, or `nil` when the catalogue
    /// has nothing matching — a position pointing at a deleted instrument, or
    /// one saved without.
    let instrument: FundInstrument?
    let instrumentID: UUID?
    /// Newest first, which is the order a DCA stack is usually read in.
    let holdings: [FundHolding]

    var id: String { instrumentID?.uuidString ?? "unmatched" }

    var symbol: String { instrument?.symbol ?? "??" }

    var name: String { instrument?.name ?? "Unknown instrument" }

    var units: Decimal {
        holdings.reduce(Decimal.zero) { total, holding in
            total + holding.units
        }
    }

    var costBasis: Decimal {
        FundSummary.totalCostBasis(of: holdings)
    }

    /// What the whole stack cost per unit — the figure a DCA buyer compares
    /// against today's price. Weighted by construction: total spent over total
    /// units, so a large purchase pulls it further than a small one.
    var averageCostPerUnit: Decimal {
        guard units > 0 else {
            return .zero
        }

        return costBasis / units
    }

    var pricePerUnit: Decimal {
        instrument?.currentPricePerUnit ?? .zero
    }

    var marketValue: Decimal {
        FundValuation.marketValue(units: units, pricePerUnit: pricePerUnit)
    }

    var unrealizedProfitLoss: Decimal {
        marketValue - costBasis
    }

    /// Return on the whole stack. Uses the summed figures rather than averaging
    /// each position's own percentage, which would weigh a token purchase the
    /// same as the one that carries the position.
    var returnPercent: Decimal {
        guard costBasis > 0 else {
            return .zero
        }

        return unrealizedProfitLoss / costBasis * 100
    }

    var isGain: Bool {
        unrealizedProfitLoss >= 0
    }

    var positionCountLabel: String {
        "\(holdings.count) positions"
    }
}

extension FundSummary {
    /// One group per instrument, largest holding first, with the unmatched
    /// positions last — they are worth nothing the app can prove, so they never
    /// lead the list.
    static func groups(
        holdings: [FundHolding],
        instruments: [FundInstrument]
    ) -> [FundPositionGroup] {
        let grouped = Dictionary(grouping: holdings) { $0.instrumentID }

        return
            grouped
            .map { instrumentID, positions in
                FundPositionGroup(
                    instrument: instrumentID.flatMap { id in
                        instruments.first { $0.id == id }
                    },
                    instrumentID: instrumentID,
                    holdings: positions.sorted { $0.boughtOn > $1.boughtOn }
                )
            }
            .sorted { first, second in
                if first.marketValue != second.marketValue {
                    return first.marketValue > second.marketValue
                }

                return first.symbol < second.symbol
            }
    }

    /// The positions held in one instrument, newest first. The detail screen
    /// re-reads this from the store rather than carrying a copy, so editing a
    /// position updates the screen that opened it.
    static func positions(
        forInstrumentID instrumentID: UUID?,
        holdings: [FundHolding]
    ) -> [FundHolding] {
        holdings
            .filter { $0.instrumentID == instrumentID }
            .sorted { $0.boughtOn > $1.boughtOn }
    }
}
