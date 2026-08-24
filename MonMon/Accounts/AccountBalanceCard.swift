import Charts
import SwiftUI

/// The per-account doughnut on the Accounts screen, with a legend naming every
/// account, its balance, and its share of the spendable total.
struct AccountBalanceCard: View {
    let slices: [AccountBalanceSlice]
    let overdraft: Decimal

    private var total: Decimal {
        AccountBalanceAllocation.total(of: slices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("WHERE YOUR CASH SITS", systemImage: "chart.pie.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    doughnut
                    legend
                }

                VStack(alignment: .leading, spacing: 20) {
                    doughnut
                        .frame(maxWidth: .infinity)
                    legend
                }
            }

            if overdraft > 0 {
                overdraftRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private var doughnut: some View {
        Chart(Array(slices.enumerated()), id: \.element.id) { index, slice in
            SectorMark(
                angle: .value("Amount", slice.amount.chartValue),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(AccountPalette.tint(at: index))
        }
        .chartLegend(.hidden)
        .frame(width: 168, height: 168)
        .overlay {
            VStack(spacing: 2) {
                Text("CASH")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(VNDCurrency.format(total))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 20)
            }
        }
        // The wedges carry no meaning on their own; the legend below states
        // every figure in text, so the chart itself is skipped by VoiceOver.
        .accessibilityHidden(true)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                legendRow(slice, tint: AccountPalette.tint(at: index))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(_ slice: AccountBalanceSlice, tint: Color) -> some View {
        HStack(spacing: 12) {
            // The symbol repeats what the colour says, so a wedge stays
            // identifiable without relying on colour.
            Image(systemName: slice.kind.legendSymbolName)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(slice.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(VNDCurrency.format(slice.amount))
                    .font(.caption)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(percentLabel(for: slice))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(MonMonTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            """
            \(slice.name), \(VNDCurrency.format(slice.amount)), \(percentLabel(for: slice)) of\
             cash
            """
        )
    }

    private func percentLabel(for slice: AccountBalanceSlice) -> String {
        let percent = AccountBalanceAllocation.percent(of: slice.amount, in: total)
        return "\(PercentInput.format(percent))%"
    }

    private var overdraftRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(MonMonTheme.danger)
                .frame(width: 28, height: 28)
                .background(MonMonTheme.danger.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Overdrawn")
                    .font(.subheadline.weight(.semibold))

                Text("Accounts below zero, kept out of the ring")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text("−\(VNDCurrency.format(overdraft))")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(MonMonTheme.danger)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Wedge colours for the per-account ring. Accounts have no colour of their own
/// — two banks would both be blue — so the ring hands out the theme's hues in
/// order and repeats once it runs out.
enum AccountPalette {
    static let tints: [Color] = [
        MonMonTheme.accent,
        MonMonTheme.bank,
        MonMonTheme.savings,
        MonMonTheme.funds,
        MonMonTheme.lent,
        MonMonTheme.Hue.pink,
        MonMonTheme.credit,
        MonMonTheme.Hue.lavender,
    ]

    static func tint(at index: Int) -> Color {
        tints[index % tints.count]
    }
}

private extension CashAccountKind {
    var legendSymbolName: String {
        switch self {
        case .cash:
            "banknote.fill"
        case .bank:
            "building.columns.fill"
        case .credit:
            "creditcard.fill"
        }
    }
}

private extension Decimal {
    /// Swift Charts takes a `Double` for the angle. Money stays `Decimal`
    /// everywhere it is summed or displayed; only the drawn angle is converted,
    /// where a rounding error is invisible.
    var chartValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

#if DEBUG
    #Preview("Account balances") {
        ScrollView {
            AccountBalanceCard(
                slices: [
                    AccountBalanceSlice(
                        accountID: UUID(),
                        name: "Techcombank",
                        kind: .bank,
                        amount: 42_000_000
                    ),
                    AccountBalanceSlice(
                        accountID: UUID(),
                        name: "Wallet",
                        kind: .cash,
                        amount: 3_500_000
                    ),
                ],
                overdraft: 1_200_000
            )
            .padding(20)
        }
        .background(MonMonTheme.canvas)
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
