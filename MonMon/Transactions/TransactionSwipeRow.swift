import SwiftUI

/// One touch resolves to exactly one intent. This keeps a horizontal swipe from
/// falling through to the row's detail action when the finger lifts.
enum TransactionRowGestureIntent: Equatable {
    case tap
    case swipe
    case scroll

    private static let tapTolerance: CGFloat = 8

    static func resolved(after translation: CGSize) -> Self {
        if max(abs(translation.width), abs(translation.height)) <= tapTolerance {
            return .tap
        }

        if TransactionSwipeReveal.horizontalTranslation(in: translation) != nil {
            return .swipe
        }

        return .scroll
    }
}

/// Which action is resting behind a transaction after a horizontal drag.
/// Positive movement follows the finger and exposes delete on the leading edge;
/// negative movement exposes edit on the trailing edge.
enum TransactionSwipeReveal: Equatable {
    case none
    case delete
    case edit

    static let actionWidth: CGFloat = 84
    private static let threshold: CGFloat = actionWidth / 2
    private static let horizontalDominance: CGFloat = 1.15

    var offset: CGFloat {
        switch self {
        case .none:
            0
        case .delete:
            Self.actionWidth
        case .edit:
            -Self.actionWidth
        }
    }

    static func resolved(after translation: CGSize, from current: Self) -> Self {
        guard let horizontalTranslation = horizontalTranslation(in: translation) else {
            return current
        }

        let proposedOffset = current.offset + horizontalTranslation

        if proposedOffset >= threshold {
            return .delete
        }

        if proposedOffset <= -threshold {
            return .edit
        }

        return .none
    }

    static func horizontalTranslation(in translation: CGSize) -> CGFloat? {
        guard abs(translation.width) > abs(translation.height) * horizontalDominance else {
            return nil
        }

        return translation.width
    }
}

enum TransactionSwipeAxis: Equatable {
    case undecided
    case horizontal
    case vertical
}

/// Persistent motion state keeps the card at the finger's last position until
/// the settling animation takes over. The drag axis is locked once recognized
/// so a diagonal movement cannot repeatedly move and reset the card.
struct TransactionSwipeMotion: Equatable {
    let reveal: TransactionSwipeReveal
    let dragOffset: CGFloat
    let axis: TransactionSwipeAxis

    init(
        reveal: TransactionSwipeReveal = .none,
        dragOffset: CGFloat = 0,
        axis: TransactionSwipeAxis = .undecided
    ) {
        self.reveal = reveal
        self.dragOffset = dragOffset
        self.axis = axis
    }

    var displayedOffset: CGFloat {
        min(
            TransactionSwipeReveal.actionWidth,
            max(-TransactionSwipeReveal.actionWidth, reveal.offset + dragOffset)
        )
    }

    func dragging(_ translation: CGSize) -> Self {
        switch axis {
        case .undecided:
            switch TransactionRowGestureIntent.resolved(after: translation) {
            case .tap:
                return self
            case .scroll:
                return Self(reveal: reveal, axis: .vertical)
            case .swipe:
                guard
                    let horizontalTranslation = TransactionSwipeReveal.horizontalTranslation(
                        in: translation
                    )
                else {
                    return self
                }

                return Self(
                    reveal: reveal,
                    dragOffset: horizontalTranslation,
                    axis: .horizontal
                )
            }
        case .horizontal:
            return Self(
                reveal: reveal,
                dragOffset: translation.width,
                axis: .horizontal
            )
        case .vertical:
            return self
        }
    }

    func endingDrag() -> Self {
        guard axis == .horizontal else {
            return Self(reveal: reveal)
        }

        return Self(
            reveal: TransactionSwipeReveal.resolved(
                after: CGSize(width: dragOffset, height: 0),
                from: reveal
            )
        )
    }
}

/// Swipe actions for a card inside a `ScrollView`, where SwiftUI's native
/// `swipeActions` modifier does not provide list-row behaviour.
struct TransactionSwipeRow<Content: View>: View {
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let content: Content

    /// Set by the screen that also reads a month swipe, so the two horizontal
    /// gestures do not both act on one drag.
    @Environment(HorizontalSwipeArbiter.self) private var arbiter: HorizontalSwipeArbiter?

    @State private var motion = TransactionSwipeMotion()

    init(
        onTap: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onTap = onTap
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack {
            actions

            content
                .contentShape(Rectangle())
                .onTapGesture {
                    handleTap()
                }
                .simultaneousGesture(rowGesture)
                .offset(x: motion.displayedOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            handleTap()
        }
        .accessibilityAction(named: Text("Edit")) {
            perform(onEdit)
        }
        .accessibilityAction(named: Text("Delete")) {
            perform(onDelete)
        }
    }

    private var actions: some View {
        HStack(spacing: 0) {
            actionButton(
                title: "Delete",
                systemImage: "trash.fill",
                tint: MonMonTheme.danger,
                isAccessible: motion.reveal == .delete
            ) {
                perform(onDelete)
            }

            Spacer(minLength: 0)

            actionButton(
                title: "Edit",
                systemImage: "pencil",
                tint: MonMonTheme.accent,
                isAccessible: motion.reveal == .edit
            ) {
                perform(onEdit)
            }
        }
    }

    private func actionButton(
        title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        isAccessible: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.body.weight(.bold))

                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(width: TransactionSwipeReveal.actionWidth)
            .frame(maxHeight: .infinity)
            .background(tint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHidden(!isAccessible)
    }

    private var rowGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                motion = motion.dragging(value.translation)

                if motion.axis == .horizontal {
                    arbiter?.claim()
                }
            }
            .onEnded { value in
                let settledMotion =
                    motion
                    .dragging(value.translation)
                    .endingDrag()

                arbiter?.release()

                withAnimation(.snappy(duration: 0.25)) {
                    motion = settledMotion
                }
            }
    }

    private func handleTap() {
        guard motion.reveal == .none else {
            withAnimation(.snappy(duration: 0.2)) {
                motion = TransactionSwipeMotion()
            }
            return
        }

        onTap()
    }

    private func perform(_ action: () -> Void) {
        withAnimation(.snappy(duration: 0.2)) {
            motion = TransactionSwipeMotion()
        }
        action()
    }
}
