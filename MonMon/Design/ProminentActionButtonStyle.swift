import SwiftUI

/// The app's own filled button, used for the one clear action a card or screen
/// is asking for — the add button under an empty list, the unlock button, the
/// sync button in Settings.
///
/// `.borderedProminent` paints its label in the system's own on-tint colour,
/// which on this theme's green track came out too close to the fill to read.
/// This borrows the selected segment of `SegmentedTabs` instead: an accent
/// capsule with `onAccent` text, so the two read as the same control family.
struct ProminentActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MonMonTheme.onAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background {
                Capsule(style: .continuous)
                    .fill(MonMonTheme.accent)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.45)
            .contentShape(Capsule(style: .continuous))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ProminentActionButtonStyle {
    /// Spelled like the system styles it replaces, so a call site reads the same
    /// way it did before.
    static var prominentAction: ProminentActionButtonStyle {
        ProminentActionButtonStyle()
    }
}

private struct HeaderIconStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(MonMonTheme.textPrimary)
    }
}

extension View {
    func headerIconStyle() -> some View {
        modifier(HeaderIconStyle())
    }
}

#if DEBUG
    #Preview("Prominent action") {
        VStack(spacing: 20) {
            Button("Add Savings Book", systemImage: "plus", action: {})
                .buttonStyle(.prominentAction)

            Button("Sync now", systemImage: "arrow.triangle.2.circlepath", action: {})
                .buttonStyle(.prominentAction)
                .disabled(true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MonMonTheme.canvas)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
