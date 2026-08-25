import SwiftUI

/// Assets and liabilities doughnuts on the Home screen, switched by tabs so
/// the card stays compact while each legend keeps its full detail.
struct AssetAllocationCard: View {
    @Environment(\.locale) private var locale

    let slices: [AssetAllocationSlice]
    let liabilities: [LiabilityAllocationSlice]

    @State private var selectedTab: AllocationTab

    init(slices: [AssetAllocationSlice], liabilities: [LiabilityAllocationSlice]) {
        self.slices = slices
        self.liabilities = liabilities
        _selectedTab = State(
            initialValue: slices.isEmpty && !liabilities.isEmpty ? .liabilities : .assets
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("ALLOCATION", systemImage: "chart.pie.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            SegmentedTabs(
                label: "Allocation type",
                selection: $selectedTab,
                options: AllocationTab.allCases,
                title: \.displayName
            )
            .accessibilityIdentifier("allocation-tabs")

            selectedAllocation
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

    @ViewBuilder
    private var selectedAllocation: some View {
        switch selectedTab {
        case .assets:
            if slices.isEmpty {
                emptyState(for: .assets)
            } else {
                AllocationDoughnut(
                    context: AllocationTab.assets.displayName(in: locale).lowercased(),
                    items: slices.map { $0.doughnutItem(in: locale) }
                )
            }
        case .liabilities:
            if liabilities.isEmpty {
                emptyState(for: .liabilities)
            } else {
                AllocationDoughnut(
                    context: AllocationTab.liabilities.displayName(in: locale).lowercased(),
                    items: liabilities.map { $0.doughnutItem(in: locale) }
                )
            }
        }
    }

    private func emptyState(for tab: AllocationTab) -> some View {
        VStack(spacing: 8) {
            Image(systemName: tab.emptySymbolName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(MonMonTheme.textMuted)
                .accessibilityHidden(true)

            Text(tab.emptyTitle)
                .font(.subheadline.weight(.semibold))

            Text(tab.emptyDescription)
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 168)
        .accessibilityElement(children: .combine)
    }
}

private enum AllocationTab: String, CaseIterable {
    case assets
    case liabilities

    /// One key, handed out as a key for a tab label and resolved as a word for
    /// the sentence the doughnut reads out.
    var nameKey: String {
        switch self {
        case .assets:
            "Assets"
        case .liabilities:
            "Liabilities"
        }
    }

    var displayName: LocalizedStringKey {
        LocalizedStringKey(nameKey)
    }

    func displayName(in locale: Locale) -> String {
        AppText.string(key: nameKey, in: locale)
    }

    var emptyTitle: LocalizedStringKey {
        switch self {
        case .assets:
            "No assets"
        case .liabilities:
            "No liabilities"
        }
    }

    var emptyDescription: LocalizedStringKey {
        switch self {
        case .assets:
            "Assets will appear here as they are recorded."
        case .liabilities:
            "Borrowed money and overdrafts will appear here."
        }
    }

    var emptySymbolName: String {
        switch self {
        case .assets:
            "chart.pie"
        case .liabilities:
            "creditcard"
        }
    }
}

private extension LiabilityAllocationSlice {
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

private extension LiabilityAllocationSlice.Kind {
    var tint: Color {
        switch self {
        case .borrowed:
            MonMonTheme.danger
        case .overdraft:
            MonMonTheme.Hue.peach
        }
    }

    var symbolName: String {
        switch self {
        case .borrowed:
            "creditcard.fill"
        case .overdraft:
            "exclamationmark.triangle.fill"
        }
    }
}

#if DEBUG
    #Preview("Allocation") {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 16) {
                AssetAllocationCard(
                    slices: [
                        AssetAllocationSlice(kind: .savings, amount: 350_000_000),
                        AssetAllocationSlice(kind: .gold, amount: 147_000_000),
                        AssetAllocationSlice(kind: .funds, amount: 93_565_000),
                        AssetAllocationSlice(kind: .cash, amount: 49_150_000),
                    ],
                    liabilities: [
                        LiabilityAllocationSlice(kind: .borrowed, amount: 20_000_000),
                        LiabilityAllocationSlice(kind: .overdraft, amount: 5_200_000),
                    ]
                )

                AssetAllocationCard(
                    slices: [AssetAllocationSlice(kind: .cash, amount: 1_250_000)],
                    liabilities: []
                )
            }
            .padding(20)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
