import Foundation

enum InvestmentSummary {
    /// Savings count at principal and funds at market value, the same weighing
    /// `AssetSummary.netWorth` already applies, so the Investments total and the
    /// Home net-worth figure can never disagree about the parked money.
    static func total(
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        instruments: [FundInstrument],
        sales: [FundSale]
    ) -> Decimal {
        AssetSummary.totalPrincipal(of: deposits)
            + FundSummary.totalMarketValue(
                of: holdings,
                instruments: instruments,
                sales: sales
            )
    }
}
