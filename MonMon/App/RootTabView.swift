import SwiftUI

enum RootTab: String, CaseIterable, Identifiable {
    case home
    case savings
    case funds
    case spending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            "Home"
        case .savings:
            "Savings"
        case .funds:
            "Funds"
        case .spending:
            "Spending"
        }
    }

    var symbolName: String {
        switch self {
        case .home:
            "house.fill"
        case .savings:
            "building.columns.fill"
        case .funds:
            "chart.line.uptrend.xyaxis"
        case .spending:
            "arrow.left.arrow.right"
        }
    }

    var accessibilityIdentifier: String {
        "\(rawValue)-tab"
    }
}

struct RootTabView: View {
    @State private var selection: RootTab = .home

    var body: some View {
        #if os(macOS)
            // macOS renders a `TabView` as a segmented control pinned to the top
            // of the window, which reads as a header. The bar below puts the
            // same four destinations where the iPhone keeps them.
            bottomBarLayout
        #else
            nativeTabs
        #endif
    }

    #if os(macOS)
        private var bottomBarLayout: some View {
            VStack(spacing: 0) {
                destinations
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }
        }

        /// Only the selected destination is built. Keeping all four alive and
        /// merely hiding them looked cheaper, but every hidden `NavigationStack`
        /// still handed its toolbar to the one window toolbar, so the header
        /// collected all four add buttons at once. A screen's own state resets
        /// on a tab switch, which is the price of each tab owning its header.
        @ViewBuilder
        private var destinations: some View {
            switch selection {
            case .home:
                AccountListView()
            case .savings:
                SavingsListView()
            case .funds:
                FundListView()
            case .spending:
                TransactionListView()
            }
        }

        private var tabBar: some View {
            HStack(spacing: 6) {
                ForEach(RootTab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(MonMonTheme.hero)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(MonMonTheme.border)
                    .frame(height: 1)
            }
        }

        private func tabButton(_ tab: RootTab) -> some View {
            let isSelected = selection == tab

            return Button {
                selection = tab
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: tab.symbolName)
                        .font(.system(size: 16, weight: .semibold))

                    Text(tab.title)
                        .font(.caption2.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                // The filled pill, not the tint alone, marks the current tab.
                .background(
                    isSelected ? MonMonTheme.accent.opacity(0.16) : .clear,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSelected ? MonMonTheme.accent : MonMonTheme.textMuted)
            .accessibilityIdentifier(tab.accessibilityIdentifier)
            .accessibilityLabel(tab.title)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        }
    #else
        private var nativeTabs: some View {
            TabView(selection: $selection) {
                AccountListView()
                    .tabItem {
                        Label(RootTab.home.title, systemImage: RootTab.home.symbolName)
                    }
                    .accessibilityIdentifier(RootTab.home.accessibilityIdentifier)
                    .tag(RootTab.home)

                SavingsListView()
                    .tabItem {
                        Label(RootTab.savings.title, systemImage: RootTab.savings.symbolName)
                    }
                    .accessibilityIdentifier(RootTab.savings.accessibilityIdentifier)
                    .tag(RootTab.savings)

                FundListView()
                    .tabItem {
                        Label(RootTab.funds.title, systemImage: RootTab.funds.symbolName)
                    }
                    .accessibilityIdentifier(RootTab.funds.accessibilityIdentifier)
                    .tag(RootTab.funds)

                TransactionListView()
                    .tabItem {
                        Label(RootTab.spending.title, systemImage: RootTab.spending.symbolName)
                    }
                    .accessibilityIdentifier(RootTab.spending.accessibilityIdentifier)
                    .tag(RootTab.spending)
            }
        }
    #endif
}

#if DEBUG
    #Preview("Tabs · accounts") {
        RootTabView()
            .modelContainer(PreviewData.populated)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
