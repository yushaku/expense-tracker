import SwiftUI

/// The app's own segmented control, used wherever a screen switches between two
/// or three views of the same data — savings against funds, income against
/// expense, day against month.
///
/// `Picker(.segmented)` refused three things the screens wanted: it sizes to its
/// widest label rather than the card it sits in, it paints in the system tint
/// instead of the theme's, and on Mac it snaps between segments with no motion.
/// This draws the track and slides a capsule under the selection instead, so the
/// eye can follow the switch.
struct SegmentedTabs<Value: Hashable>: View {
    /// Read by VoiceOver as the control's name, since the tabs carry no visible
    /// label of their own.
    let label: LocalizedStringKey

    let options: [Value]
    let title: (Value) -> LocalizedStringKey

    @Binding var selection: Value

    @Namespace private var indicator

    init(
        label: LocalizedStringKey,
        selection: Binding<Value>,
        options: [Value],
        title: @escaping (Value) -> LocalizedStringKey
    ) {
        self.label = label
        _selection = selection
        self.options = options
        self.title = title
    }

    private static var trackPadding: CGFloat { 4 }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                segment(option)
            }
        }
        .padding(Self.trackPadding)
        .background {
            Capsule(style: .continuous)
                .fill(MonMonTheme.field)
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private func segment(_ option: Value) -> some View {
        let isSelected = option == selection

        return Button {
            // The animation lives on the write rather than on the view so the
            // capsule only slides for a tap, and does not fly in when the
            // screen first draws or when the selection changes from elsewhere.
            withAnimation(.snappy(duration: 0.28, extraBounce: 0.08)) {
                selection = option
            }
        } label: {
            Text(title(option))
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? MonMonTheme.onAccent : MonMonTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 9)
                .padding(.horizontal, 10)
                // Every segment takes an equal share of the track, so the tabs
                // stay put as the labels change width.
                .frame(maxWidth: .infinity)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(MonMonTheme.accent)
                            .matchedGeometryEffect(id: "segmented-tabs-indicator", in: indicator)
                    }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The same switch the tabs make, made by dragging the screen sideways instead.
///
/// The tabs stay the visible control; this only spares the thumb the trip up to
/// them. It rides alongside the scroll gesture rather than replacing it, so a
/// list still scrolls and a row still taps.
private struct SegmentSwipe<Value: Hashable>: ViewModifier {
    @Binding var selection: Value
    let options: [Value]

    @Environment(\.layoutDirection) private var layoutDirection

    /// How far sideways a drag has to travel before it counts as a swipe.
    private static var threshold: CGFloat { 60 }

    /// How much more sideways than vertical it has to be, so a diagonal flick
    /// aimed at the scroll view does not change the tab underneath it.
    private static var dominance: CGFloat { 1.5 }

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { drag in
                    step(by: drag.translation)
                }
        )
    }

    private func step(by translation: CGSize) {
        guard abs(translation.width) > Self.threshold,
            abs(translation.width) > abs(translation.height) * Self.dominance,
            let current = options.firstIndex(of: selection)
        else {
            return
        }

        // Dragging left reveals what is to the right of the current tab, and in
        // a right-to-left layout the tabs themselves are laid out the other way.
        let backwards =
            layoutDirection == .rightToLeft
            ? translation.width < 0
            : translation.width > 0
        let next = backwards ? current - 1 : current + 1

        // The ends do not wrap; a swipe past them leaves the tab where it is,
        // the way a stack of pages stops rather than looping.
        guard options.indices.contains(next) else {
            return
        }

        withAnimation(.snappy(duration: 0.28, extraBounce: 0.08)) {
            selection = options[next]
        }
    }
}

extension View {
    /// Lets a sideways drag anywhere on this view move between the options a
    /// `SegmentedTabs` above it is showing.
    func swipeBetweenSegments<Value: Hashable>(
        selection: Binding<Value>,
        options: [Value]
    ) -> some View {
        modifier(SegmentSwipe(selection: selection, options: options))
    }
}

#if DEBUG
    private struct SegmentedTabsPreview: View {
        @State private var kind: TransactionKind = .expense
        @State private var scope: TransactionRangeScope = .month

        var body: some View {
            VStack(spacing: 24) {
                SegmentedTabs(
                    label: "Direction",
                    selection: $kind,
                    options: TransactionKind.allCases,
                    title: \.displayName
                )

                SegmentedTabs(
                    label: "Period",
                    selection: $scope,
                    options: TransactionRangeScope.allCases,
                    title: \.displayName
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MonMonTheme.canvas)
        }
    }

    #Preview("Segmented tabs") {
        SegmentedTabsPreview()
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
