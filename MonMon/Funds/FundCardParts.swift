import SwiftUI

/// The pieces a fund card is built from, shared by the group card and the
/// position cards inside it so the two read as the same object at two zoom
/// levels rather than as two designs.
struct FundMetric: Identifiable {
    /// The key naming the column, and the figure under it. The figure is
    /// already formatted, so only the name goes through the catalogue.
    let titleKey: String
    let value: String

    var title: LocalizedStringKey { LocalizedStringKey(titleKey) }
    var id: String { titleKey }
}

/// Metrics two to a row. Unit prices and cost bases both run long in đồng, and
/// four across shrank every one of them past reading on an iPhone.
struct FundMetricGrid: View {
    @Environment(\.locale) private var locale

    let metrics: [FundMetric]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { metric in
                        cell(metric)
                    }

                    // A trailing odd metric keeps its half of the row rather
                    // than stretching across both columns.
                    if row.count == 1 {
                        Color.clear
                            .frame(height: 0)
                    }
                }
            }
        }
    }

    private var rows: [[FundMetric]] {
        stride(from: 0, to: metrics.count, by: 2).map { start in
            Array(metrics[start..<min(start + 2, metrics.count)])
        }
    }

    private func cell(_ metric: FundMetric) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(metric.title)
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(metric.value)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Profit and loss never rests on colour alone: the arrow and the explicit sign
/// carry the meaning, and the tint only reinforces it.
struct FundProfitLossRow: View {
    let profitLoss: Decimal
    let returnPercent: Decimal

    private var isGain: Bool {
        profitLoss >= 0
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isGain ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.weight(.bold))
                .accessibilityHidden(true)

            Text(description)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Text(isGain ? "UNREALIZED GAIN" : "UNREALIZED LOSS")
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .foregroundStyle(isGain ? MonMonTheme.gain : MonMonTheme.danger)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            (isGain ? MonMonTheme.gain : MonMonTheme.danger).opacity(0.14),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var description: String {
        let sign = isGain ? "+" : "−"
        let amount = VNDCurrency.format(abs(profitLoss))
        let percent = PercentInput.format(abs(returnPercent))
        return "\(sign)\(amount) (\(sign)\(percent)%)"
    }
}

/// Where the price came from and when it is from. A stale price says so in
/// words and carries a symbol; colour only reinforces it.
struct FundPriceStatusRow: View {
    @Environment(\.locale) private var locale

    let instrument: FundInstrument?
    /// Passed in rather than read from the clock, so a preview and a test both
    /// get a stable answer for whether the price is stale.
    let asOf: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Image(systemName: symbolName)
                    .font(.caption2.weight(.semibold))
                    .accessibilityHidden(true)

                Text(description)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 8)
            }

            if let spreadDescription {
                Text(spreadDescription)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(isStale ? MonMonTheme.danger : MonMonTheme.textSecondary)
        .accessibilityIdentifier("quote-status")
    }

    var isStale: Bool {
        guard let instrument, instrument.autoQuoteEnabled else {
            return false
        }

        return TradingCalendar.isStale(
            priceAsOf: instrument.priceAsOf,
            kind: instrument.kind,
            asOf: asOf
        )
    }

    private var symbolName: String {
        if instrument == nil {
            return "questionmark.circle"
        }

        return isStale ? "exclamationmark.circle.fill" : "clock"
    }

    private var description: String {
        guard let instrument else {
            return AppText.string("Instrument missing — value cannot be worked out", in: locale)
        }

        let day = TransactionPeriod.day(instrument.priceAsOf, in: locale)
        let base =
            "\(instrument.priceLabel(in: locale)) \(day) · "
            + "\(instrument.source.displayName(in: locale))"
        return isStale ? AppText.string("\(base) · Stale", in: locale) : base
    }

    private var spreadDescription: String? {
        guard let instrument, instrument.kind == .gold else {
            return nil
        }
        let buy = VNDCurrency.formatUnitPrice(instrument.currentPricePerUnit)
        let sell =
            instrument.askPricePerUnit > 0
            ? VNDCurrency.formatUnitPrice(instrument.askPricePerUnit) : "—"
        return AppText.string("Shop buys \(buy) · sells \(sell) per lượng", in: locale)
    }
}

/// The rounded surface every fund card sits on.
struct FundCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MonMonTheme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
    }
}

extension View {
    func fundCardBackground() -> some View {
        modifier(FundCardBackground())
    }
}
