import SwiftUI

/// The transaction defaults on their own, opened as a sheet from the Spending
/// screen so they can be changed where they are noticed rather than only from
/// the Settings tab.
struct TransactionDefaultsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(macOS)
            form
                .frame(minWidth: 460, minHeight: 420)
        #else
            form
        #endif
    }

    private var form: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        TransactionDefaultsCard()
                        QuickExpensePresetsCard()
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Defaults")
            .accessibilityIdentifier("transaction-defaults")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }
}
