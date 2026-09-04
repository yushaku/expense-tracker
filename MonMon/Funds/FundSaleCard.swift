import SwiftUI

/// One sale, under the position it came out of: how much went, at what price,
/// where the money landed, and what it made.
struct FundSaleCard: View {
    @Environment(\.locale) private var locale

    let sale: FundSale
    /// What the sold units cost. Comes from the lot rather than the sale, so the
    /// two can never disagree about it.
    let costPerUnit: Decimal
    let isGold: Bool
    let proceedsAccountName: String?
    /// The coin a swap bought, when this disposal was a swap. `nil` for a sale
    /// that paid into an account.
    var swappedIntoSymbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: sale.isSwap ? "arrow.left.arrow.right" : "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(sale.isSwap ? MonMonTheme.crypto : MonMonTheme.funds)
                    .frame(width: 32, height: 32)
                    .background(MonMonTheme.funds.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(quantityDescription)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(VNDCurrency.format(sale.proceeds))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(profitLossDescription)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(isGain ? MonMonTheme.gain : MonMonTheme.danger)
                }
            }

            if !sale.note.isEmpty {
                Text(sale.note)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var profitLoss: Decimal {
        sale.realizedProfitLoss(costPerUnit: costPerUnit)
    }

    private var isGain: Bool {
        profitLoss >= 0
    }

    /// The sign is spelled out beside the figure, so the colour beside it is
    /// only ever a second way of saying the same thing.
    private var profitLossDescription: String {
        let sign = isGain ? "+" : "−"
        return "\(sign)\(VNDCurrency.format(abs(profitLoss)))"
    }

    private var quantityDescription: String {
        isGold
            ? GoldWeight.label(luong: sale.units)
            : "\(UnitQuantity.format(sale.units)) \(AppText.string("units", in: locale))"
    }

    private var subtitle: String {
        let day = TransactionPeriod.day(sale.soldAt, in: locale)
        let price = VNDCurrency.formatUnitPrice(sale.pricePerUnit)

        // A swap says which coin it became rather than naming an account,
        // because no account was involved.
        if sale.isSwap {
            guard let swappedIntoSymbol else {
                return "\(day) · \(price) · \(AppText.string("swapped", in: locale))"
            }
            let forWord = AppText.string("for", in: locale)
            return "\(day) · \(price) · \(forWord) \(swappedIntoSymbol)"
        }

        guard let proceedsAccountName else {
            return "\(day) · \(price)"
        }

        let into = AppText.string("into", in: locale)
        return "\(day) · \(price) · \(into) \(proceedsAccountName)"
    }
}
