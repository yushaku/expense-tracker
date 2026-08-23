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
    let label: String

    let options: [Value]
    let title: (Value) -> String

    @Binding var selection: Value

    @Namespace private var indicator

    init(
        label: String,
        selection: Binding<Value>,
        options: [Value],
        title: @escaping (Value) -> String
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
