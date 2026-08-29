import Charts
import SwiftUI

/// One wedge of a doughnut, already resolved to the words and colour it is
/// drawn with, so the chart itself stays free of the model it came from.
struct AllocationDoughnutItem: Identifiable {
    let id: String
    let name: String
    let amount: Decimal
    let tint: Color
    let symbolName: String
    let valueLabel: String?

    init(
        id: String,
        name: String,
        amount: Decimal,
        tint: Color,
        symbolName: String,
        valueLabel: String? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.tint = tint
        self.symbolName = symbolName
        self.valueLabel = valueLabel
    }
}

/// A ring of wedges with its total in the hole and a legend beside it, shared
/// by every card that splits one figure into named parts.
struct AllocationDoughnut: View {
    /// What the legend says each wedge is a share *of*, read out by VoiceOver.
    let context: String
    let items: [AllocationDoughnutItem]
    let totalLabel: String
    let totalValueLabel: String?
    let showsLegend: Bool

    /// The wedge the owner tapped, held by id rather than by index so a card
    /// that reorders or refreshes its parts keeps the same one picked.
    @State private var selectedItemID: String?

    private static let diameter: CGFloat = 168
    private static let innerRadiusRatio: CGFloat = 0.62

    private var total: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.amount }
    }

    init(
        context: String,
        items: [AllocationDoughnutItem],
        totalLabel: String = "TOTAL",
        totalValueLabel: String? = nil,
        showsLegend: Bool = true
    ) {
        self.context = context
        self.items = items
        self.totalLabel = totalLabel
        self.totalValueLabel = totalValueLabel
        self.showsLegend = showsLegend
    }

    @ViewBuilder
    var body: some View {
        if showsLegend {
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
        } else {
            doughnut
                .frame(maxWidth: .infinity)
        }
    }

    private var doughnut: some View {
        Chart(items) { item in
            SectorMark(
                angle: .value("Amount", item.amount.doubleValue),
                innerRadius: .ratio(Self.innerRadiusRatio),
                // The tapped wedge stands out of the ring. Every other wedge
                // keeps the smaller radius whether or not one is picked, so the
                // doughnut never resizes the card around it.
                outerRadius: .ratio(isSelected(item) ? 1 : 0.9),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(item.tint)
            .opacity(selectedItemID == nil || isSelected(item) ? 1 : 0.3)
        }
        .chartLegend(.hidden)
        .frame(width: Self.diameter, height: Self.diameter)
        .overlay {
            centerLabel
        }
        // The whole square takes the tap, and where in it the tap landed is
        // turned into a wedge below. Charts' own angle selection reported
        // nothing here, and this also gives the hole in the middle a job:
        // clearing the pick.
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture()
                .onEnded { tap in
                    withAnimation(.snappy(duration: 0.28)) {
                        selectItem(at: tap.location)
                    }
                }
        )
        .animation(.snappy(duration: 0.28), value: selectedItemID)
        // A picked wedge belongs to the parts on show; a new set makes it point
        // at something that may no longer be there.
        .onChange(of: items.map(\.id)) { _, _ in
            selectedItemID = nil
        }
        // The wedges carry no meaning on their own; the legend below states
        // every figure in text, so the chart itself is skipped by VoiceOver.
        .accessibilityHidden(true)
    }

    /// The hole in the middle carries the total until a wedge is tapped, and
    /// then that wedge's name and share, which is the question a tap on a
    /// doughnut is asking.
    @ViewBuilder
    private var centerLabel: some View {
        if let item = selectedItem {
            VStack(spacing: 2) {
                Image(systemName: item.symbolName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(item.tint)

                Text(item.name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(percentLabel(for: item))
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())

                Text(valueLabel(for: item))
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
            .padding(.horizontal, 22)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else {
            VStack(spacing: 2) {
                Text(totalLabel.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(totalValueLabel ?? VNDCurrency.format(total))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 20)
            }
            .transition(.opacity)
        }
    }

    private var selectedItem: AllocationDoughnutItem? {
        items.first { $0.id == selectedItemID }
    }

    private func isSelected(_ item: AllocationDoughnutItem) -> Bool {
        selectedItem?.id == item.id
    }

    /// Turns a point in the doughnut into the wedge under it: how far round the
    /// ring the tap sits, clockwise from twelve o'clock, is the wedge's share of
    /// the total run up to it.
    private func selectItem(at location: CGPoint) {
        let radius = Self.diameter / 2
        let across = location.x - radius
        let down = location.y - radius
        let distance = (across * across + down * down).squareRoot()

        // The hole in the middle and anything past the ring clear the pick, so
        // a tap that missed every wedge is never read as choosing one.
        guard distance >= radius * Self.innerRadiusRatio, distance <= radius else {
            selectedItemID = nil
            return
        }

        var turn = atan2(across, -down) / (2 * .pi)

        if turn < 0 {
            turn += 1
        }

        let tapped = AllocationDoughnut.item(atTurn: Double(turn), in: items)

        // Tapping the wedge already picked puts the total back.
        selectedItemID = tapped?.id == selectedItemID ? nil : tapped?.id
    }

    /// The wedge covering `turn`, a fraction of one lap clockwise from twelve
    /// o'clock. Nothing here draws, so the same turn picks the same wedge
    /// wherever it is asked from.
    static func item(
        atTurn turn: Double,
        in items: [AllocationDoughnutItem]
    ) -> AllocationDoughnutItem? {
        let total = items.reduce(Decimal.zero) { $0 + $1.amount }

        guard total > 0, turn >= 0, turn < 1 else {
            return nil
        }

        var passed = Decimal.zero

        for item in items {
            passed += item.amount

            if Decimal(turn) < passed / total {
                return item
            }
        }

        return items.last
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                legendRow(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(_ item: AllocationDoughnutItem) -> some View {
        HStack(spacing: 12) {
            // The symbol repeats what the colour says, so the wedge is
            // identifiable without relying on colour.
            Image(systemName: item.symbolName)
                .font(.footnote.weight(.bold))
                .foregroundStyle(item.tint)
                .frame(width: 28, height: 28)
                .background(item.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))

                Text(valueLabel(for: item))
                    .font(.caption)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(percentLabel(for: item))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(MonMonTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            """
            \(item.name), \(valueLabel(for: item)), \(percentLabel(for: item)) of \
            \(context)
            """
        )
    }

    private func valueLabel(for item: AllocationDoughnutItem) -> String {
        item.valueLabel ?? VNDCurrency.format(item.amount)
    }

    private func percentLabel(for item: AllocationDoughnutItem) -> String {
        let percent = AssetAllocation.percent(of: item.amount, in: total)
        return "\(PercentInput.format(percent))%"
    }
}

extension AssetAllocationSlice.Kind {
    var tint: Color {
        switch self {
        case .cash:
            MonMonTheme.accent
        case .savings:
            MonMonTheme.savings
        case .funds:
            MonMonTheme.funds
        case .gold:
            MonMonTheme.Hue.peach
        case .lent:
            MonMonTheme.lent
        }
    }

    var symbolName: String {
        switch self {
        case .cash:
            "banknote.fill"
        case .savings:
            "building.columns.fill"
        case .funds:
            "chart.line.uptrend.xyaxis"
        case .gold:
            "seal.fill"
        case .lent:
            "tray.and.arrow.up.fill"
        }
    }
}

extension AssetAllocationSlice {
    func doughnutItem(in locale: Locale) -> AllocationDoughnutItem {
        AllocationDoughnutItem(
            id: id,
            name: kind.displayName(in: locale),
            amount: amount,
            tint: kind.tint,
            symbolName: kind.symbolName
        )
    }
}

private extension Decimal {
    /// Swift Charts takes a `Double` for the angle. Money stays `Decimal`
    /// everywhere it is summed or displayed; only the drawn angle is converted,
    /// where a rounding error is invisible.
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
