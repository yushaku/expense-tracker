import SwiftUI

/// The add action for a list, floating over the bottom-trailing corner instead
/// of sitting in the window toolbar.
///
/// It lands under the thumb on iPhone and beside the scroll bar on Mac, where
/// the toolbar sits furthest from wherever the owner was already looking. Lists
/// leave room for it beneath their last card so nothing hides behind it.
struct FloatingAddButton: View {
    let title: LocalizedStringKey
    let accessibilityIdentifier: String
    let action: () -> Void

    /// How much room a list should leave below its content so the last card
    /// clears the button.
    static let contentInset: CGFloat = 88

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 56, height: 56)
                .background(MonMonTheme.accent, in: Circle())
                .shadow(color: .black.opacity(0.28), radius: 12, y: 4)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(title)
    }
}

#if DEBUG
    #Preview("Floating add") {
        ZStack(alignment: .bottomTrailing) {
            MonMonTheme.canvas
                .ignoresSafeArea()

            FloatingAddButton(
                title: "Add Transaction",
                accessibilityIdentifier: "add-transaction",
                action: {}
            )
        }
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
