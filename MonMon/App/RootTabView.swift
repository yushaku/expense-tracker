import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            AccountListView()
                .tabItem {
                    Label("Cash", systemImage: "wallet.bifold.fill")
                }
                .accessibilityIdentifier("cash-tab")

            SavingsListView()
                .tabItem {
                    Label("Savings", systemImage: "building.columns.fill")
                }
                .accessibilityIdentifier("savings-tab")

            FundListView()
                .tabItem {
                    Label("Funds", systemImage: "chart.line.uptrend.xyaxis")
                }
                .accessibilityIdentifier("funds-tab")

            TransactionListView()
                .tabItem {
                    Label("Spending", systemImage: "arrow.left.arrow.right")
                }
                .accessibilityIdentifier("spending-tab")
        }
    }
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
