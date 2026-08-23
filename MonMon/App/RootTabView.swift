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
