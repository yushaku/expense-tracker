import SwiftUI

/// Declaration order is the order of the bar: daily transactions come first,
/// the broader report follows, then longer-term money and settings.
enum RootTab: String, CaseIterable, Identifiable {
    case spending
    case report
    case investments
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .report:
            "Report"
        case .investments:
            "Investments"
        case .spending:
            "Spending"
        case .settings:
            "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .report:
            "chart.bar.fill"
        case .investments:
            "chart.pie.fill"
        case .spending:
            "arrow.left.arrow.right"
        case .settings:
            "gearshape.fill"
        }
    }

    var accessibilityIdentifier: String {
        "\(rawValue)-tab"
    }
}

struct RootTabView: View {
    @State private var selection: RootTab = .spending

    #if os(macOS)
        @Namespace private var pill
    #endif

    var body: some View {
        #if os(macOS)
            // macOS renders a `TabView` as a segmented control pinned to the top
            // of the window, which reads as a header. The bar below puts the
            // same destinations where the iPhone keeps them.
            bottomBarLayout
        #else
            nativeTabs
        #endif
    }

    #if os(macOS)
        private static let pillID = "selected-tab"

        private var bottomBarLayout: some View {
            VStack(spacing: 0) {
                destinations
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }
        }

        /// Only the selected destination is built. Keeping them all alive and
        /// merely hiding them looked cheaper, but every hidden `NavigationStack`
        /// still handed its toolbar to the one window toolbar, so the header
        /// collected every add button at once. A screen's own state resets on a
        /// tab switch, which is the price of each tab owning its header.
        @ViewBuilder
        private var destinations: some View {
            switch selection {
            case .report:
                AccountListView()
            case .investments:
                InvestmentsView()
            case .spending:
                TransactionListView()
            case .settings:
                SettingsView()
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
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.08)) {
                    selection = tab
                }
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
                // One pill moves between the buttons rather than each drawing
                // its own, so it slides across instead of blinking on and off.
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MonMonTheme.accent.opacity(0.16))
                            .matchedGeometryEffect(id: Self.pillID, in: pill)
                    }
                }
                // The padded frame, not just the glyph, takes the click. A
                // `.clear` background draws nothing and so catches nothing,
                // which left only the icon itself hittable.
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSelected ? MonMonTheme.accent : MonMonTheme.textMuted)
            .animation(.snappy(duration: 0.28), value: isSelected)
            .accessibilityIdentifier(tab.accessibilityIdentifier)
            .accessibilityLabel(tab.title)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        }
    #else
        private var nativeTabs: some View {
            TabView(selection: $selection) {
                TransactionListView()
                    .tabItem {
                        Label(RootTab.spending.title, systemImage: RootTab.spending.symbolName)
                    }
                    .accessibilityIdentifier(RootTab.spending.accessibilityIdentifier)
                    .tag(RootTab.spending)

                AccountListView()
                    .tabItem {
                        Label(RootTab.report.title, systemImage: RootTab.report.symbolName)
                    }
                    .accessibilityIdentifier(RootTab.report.accessibilityIdentifier)
                    .tag(RootTab.report)

                InvestmentsView()
                    .tabItem {
                        Label(
                            RootTab.investments.title,
                            systemImage: RootTab.investments.symbolName
                        )
                    }
                    .accessibilityIdentifier(RootTab.investments.accessibilityIdentifier)
                    .tag(RootTab.investments)

                SettingsView()
                    .tabItem {
                        Label(RootTab.settings.title, systemImage: RootTab.settings.symbolName)
                    }
                    .accessibilityIdentifier(RootTab.settings.accessibilityIdentifier)
                    .tag(RootTab.settings)
            }
        }
    #endif
}

/// Root tabs keep their title compact so the navigation bar identifies each
/// screen without reserving the large-title header space.
private struct CompactRootNavigationTitle: ViewModifier {
    let title: String

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        #else
            content.navigationTitle(title)
        #endif
    }
}

extension View {
    func compactRootNavigationTitle(_ title: String) -> some View {
        modifier(CompactRootNavigationTitle(title: title))
    }
}

#if DEBUG
    #Preview("Tabs · spending") {
        RootTabView()
            .modelContainer(PreviewData.populated)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
