import SwiftUI

/// What a stretch of time came to: the net at the top, the split that produced
/// it, and the two directions side by side.
///
/// The card reads a period rather than owning one, so Report and a single day
/// can put the same summary above the details they present.
struct SpendingOverviewCard: View {
    @Environment(\.locale) private var locale

    /// Names the period. Handed in rather than taken from the range, so a screen
    /// showing one day can spell that day out in full.
    let title: String
    let income: Decimal
    let expense: Decimal
    let count: Int

    /// Whether the bar is spelling out its two shares. Off by default: the bar
    /// already says which way the period leaned, and the figures beside it say
    /// by how much. The percentages are the third reading, asked for by a tap.
    @State private var isShowingShares = false

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
        // The surface every other card on the screen sits on. A wash of the
        // period's own colour set this one apart from its neighbours, which
        // said the summary was a different kind of thing than the cards under
        // it; the figure itself carries the colour instead.
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
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
            .background(MonMonTheme.field, in: Capsule())
            .accessibilityLabel(countLabel)
    }

    /// The one figure the card exists for, centred and large enough to be read
    /// across a room. It needs no label: it sits under the period it belongs to,
    /// carries its own sign, and wears the colour of what the period did.
    private var netAmount: some View {
        Text(signed(net))
            .font(.system(size: 44, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .foregroundStyle(netTint)
            .contentTransition(.numericText())
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AppText.string("Net \(signed(net))", in: locale))
    }

    /// How much of the money that moved came in against how much went out. It
    /// says in one glance what two figures otherwise have to be compared to say,
    /// and a tap makes it say it in numbers.
    private var splitBar: some View {
        VStack(spacing: 8) {
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
            .frame(height: isShowingShares ? 12 : 8)

            if isShowingShares {
                shareRow
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy(duration: 0.28)) {
                isShowingShares.toggle()
            }
        }
        .animation(.snappy(duration: 0.3), value: share(of: income))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(splitAccessibilityLabel)
        .accessibilityHint("Shows or hides the two shares.")
        .accessibilityIdentifier("spending-split")
    }

    /// The two shares, each under its own end of the bar.
    private var shareRow: some View {
        HStack(spacing: 8) {
            Text(sharePercent(of: income))
                .foregroundStyle(MonMonTheme.gain)

            Spacer(minLength: 8)

            Text(sharePercent(of: expense))
                .foregroundStyle(MonMonTheme.danger)
        }
        .font(.caption2.weight(.bold))
        .monospacedDigit()
        .lineLimit(1)
        .contentTransition(.numericText())
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var splitAccessibilityLabel: String {
        guard flow > 0 else {
            return AppText.string("Nothing recorded", in: locale)
        }

        return AppText.string(
            "Income \(sharePercent(of: income)), expense \(sharePercent(of: expense))",
            in: locale
        )
    }

    private func sharePercent(of amount: Decimal) -> String {
        flow > 0 ? Percentage.label(of: amount, in: flow) : "0%"
    }

    private func directionTile(_ kind: TransactionKind, amount: Decimal) -> some View {
        let tint = kind == .income ? MonMonTheme.gain : MonMonTheme.danger

        return HStack(alignment: .center, spacing: 10) {
            // The figure is what the tile is for, so it takes the room and the
            // weight; the name and the arrow that label it stack out of its way.
            Text(VNDCurrency.format(amount))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(MonMonTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(kind.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: kind.symbolName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(0.18), in: Circle())
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
            "\(kind.displayName(in: locale)) \(VNDCurrency.format(amount))"
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

    /// A count reads as a whole sentence rather than a number glued to a word:
    /// how a language counts things is its own business, and Vietnamese does not
    /// change the noun at all.
    private var countLabel: String {
        AppText.string("\(count) transactions", in: locale)
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
