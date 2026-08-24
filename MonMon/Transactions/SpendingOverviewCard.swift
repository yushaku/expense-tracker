import SwiftUI

/// What a stretch of time came to: the net at the top, the split that produced
/// it, and the two directions side by side.
///
/// The card reads a period rather than owning one, so the Spending screen and a
/// single day both put the same summary above their list.
struct SpendingOverviewCard: View {
    /// Names the period. Handed in rather than taken from the range, so a screen
    /// showing one day can spell that day out in full.
    let title: String
    let income: Decimal
    let expense: Decimal
    let count: Int

    private var net: Decimal {
        income - expense
    }

    private var flow: Decimal {
        income + expense
    }

    /// The colour the whole card leans on: what the period did, in one hue. A
    /// period with nothing in it stays neutral rather than claiming a surplus.
    private var netTint: Color {
        if flow == 0 {
            return MonMonTheme.accent
        }

        return net < 0 ? MonMonTheme.danger : MonMonTheme.gain
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            netAmount

            splitBar

            HStack(spacing: 12) {
                directionTile(.income, amount: income)
                directionTile(.expense, amount: expense)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.hero)
        }
        // A wash of the period's own colour, strongest behind the figure it
        // belongs to, so the card is read before it is read out.
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [netTint.opacity(0.22), netTint.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(netTint.opacity(0.28), lineWidth: 1)
        }
        .animation(.snappy(duration: 0.28), value: netTint)
        .accessibilityIdentifier("spending-overview")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(MonMonTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            countPill
        }
    }

    private var countPill: some View {
        Label("\(count)", systemImage: "rectangle.stack.fill")
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(MonMonTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(MonMonTheme.surface.opacity(0.7), in: Capsule())
            .accessibilityLabel(countLabel)
    }

    private var netAmount: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NET")
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(signed(net))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(MonMonTheme.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Net \(signed(net))")
    }

    /// How much of the money that moved came in against how much went out. It
    /// says in one glance what two figures otherwise have to be compared to say.
    private var splitBar: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let incomeWidth = width * share(of: income)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MonMonTheme.danger.opacity(flow == 0 ? 0.18 : 0.85))

                Capsule()
                    .fill(MonMonTheme.gain)
                    .frame(width: max(0, min(width, incomeWidth)))
            }
        }
        .frame(height: 8)
        .animation(.snappy(duration: 0.3), value: share(of: income))
        .accessibilityHidden(true)
    }

    private func directionTile(_ kind: TransactionKind, amount: Decimal) -> some View {
        let tint = kind == .income ? MonMonTheme.gain : MonMonTheme.danger

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbolName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(0.18), in: Circle())

                Text(kind.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(VNDCurrency.format(amount))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(MonMonTheme.textPrimary)

            Text(shareLabel(of: amount))
                .font(.caption2.weight(.medium))
                .foregroundStyle(MonMonTheme.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MonMonTheme.surface.opacity(0.75))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(kind.displayName) \(VNDCurrency.format(amount)), \(shareLabel(of: amount))"
        )
    }

    /// The sign is written out rather than left to the minus the formatter would
    /// place, so a surplus reads as clearly as a shortfall.
    private func signed(_ amount: Decimal) -> String {
        let magnitude = amount < 0 ? -amount : amount
        let sign = amount < 0 ? "−" : "+"

        return "\(sign)\(VNDCurrency.format(magnitude))"
    }

    private func share(of amount: Decimal) -> CGFloat {
        guard flow > 0 else {
            return 0
        }

        return CGFloat(truncating: NSDecimalNumber(decimal: amount / flow))
    }

    private func shareLabel(of amount: Decimal) -> String {
        guard flow > 0 else {
            return "Nothing recorded"
        }

        return "\(Percentage.label(of: amount, in: flow)) of what moved"
    }

    private var countLabel: String {
        count == 1 ? "1 transaction" : "\(count) transactions"
    }
}

#if DEBUG
    #Preview("Spending overview") {
        VStack(spacing: 20) {
            SpendingOverviewCard(
                title: "August 2026",
                income: 24_000_000,
                expense: 9_400_000,
                count: 18
            )

            SpendingOverviewCard(
                title: "July 2026",
                income: 3_000_000,
                expense: 8_200_000,
                count: 7
            )

            SpendingOverviewCard(title: "June 2026", income: 0, expense: 0, count: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MonMonTheme.canvas)
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
