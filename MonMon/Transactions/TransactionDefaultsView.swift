import SwiftUI

/// The defaults used by new transactions, managed from Settings.
struct TransactionDefaultsView: View {
    var body: some View {
        ScrollView {
            TransactionDefaultsCard()
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
        }
        .background(MonMonTheme.canvas)
        .navigationTitle("Transaction default")
        .accessibilityIdentifier("transaction-defaults")
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
    }
}
