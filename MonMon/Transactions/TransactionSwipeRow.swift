import SwiftUI

/// One touch resolves to exactly one intent. This keeps a horizontal swipe from
/// falling through to the row's detail action when the finger lifts.
enum TransactionRowGestureIntent: Equatable {
    case tap
    case swipe
    case scroll

    private static let tapTolerance: CGFloat = 8
    private static let horizontalDominance: CGFloat = 1.15

    static func resolved(after translation: CGSize) -> Self {
        if max(abs(translation.width), abs(translation.height)) <= tapTolerance {
            return .tap
        }

        if horizontalTranslation(in: translation) != nil {
            return .swipe
        }

        return .scroll
    }

    static func horizontalTranslation(in translation: CGSize) -> CGFloat? {
        guard abs(translation.width) > abs(translation.height) * horizontalDominance else {
            return nil
        }

        return translation.width
    }
}

/// What a swipe across a transaction is aimed at. The row moves with the
/// finger and nothing rests behind it: carry it far enough and letting go
/// performs the action, the way a mail app does it.
///
/// Movement to the right aims at delete, to the left at edit.
enum TransactionSwipeAction: Equatable {
    case delete
    case edit

    /// How far the finger carries the row before letting go acts on it. Well
    /// past a hesitant nudge, and short enough to reach without a second grab.
    static let commitDistance: CGFloat = 120

    static func aimed(by translation: CGFloat) -> Self? {
        if translation > 0 {
            return .delete
        }

        if translation < 0 {
            return .edit
        }

        return nil
    }
}

enum TransactionSwipeAxis: Equatable {
    case undecided
    case horizontal
    case vertical
}

/// Where the row is under the finger. The drag axis is locked once recognized
/// so a diagonal movement cannot repeatedly move and reset the row.
struct TransactionSwipeMotion: Equatable {
    let dragOffset: CGFloat
    let axis: TransactionSwipeAxis

    init(dragOffset: CGFloat = 0, axis: TransactionSwipeAxis = .undecided) {
        self.dragOffset = dragOffset
        self.axis = axis
    }

    var displayedOffset: CGFloat {
        axis == .horizontal ? dragOffset : 0
    }

    /// The action the finger is heading towards, shown behind the row from the
    /// first point of movement so the swipe says what it will do.
    var aimedAction: TransactionSwipeAction? {
        TransactionSwipeAction.aimed(by: displayedOffset)
    }

    /// Whether the row has been carried far enough that letting go acts.
    var isCommitted: Bool {
        abs(displayedOffset) >= TransactionSwipeAction.commitDistance
    }

    /// What letting go now would perform, if anything.
    var committedAction: TransactionSwipeAction? {
        isCommitted ? aimedAction : nil
    }

    func dragging(_ translation: CGSize) -> Self {
        switch axis {
        case .undecided:
            switch TransactionRowGestureIntent.resolved(after: translation) {
            case .tap:
                return self
            case .scroll:
                return Self(axis: .vertical)
            case .swipe:
                guard
                    let horizontalTranslation = TransactionRowGestureIntent.horizontalTranslation(
                        in: translation
                    )
                else {
                    return self
                }

                return Self(dragOffset: horizontalTranslation, axis: .horizontal)
            }
        case .horizontal:
            return Self(dragOffset: translation.width, axis: .horizontal)
        case .vertical:
            return self
        }
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
            background

            content
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .simultaneousGesture(rowGesture)
                .offset(x: motion.displayedOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sensoryFeedback(.impact(weight: .light), trigger: motion.isCommitted) { _, isCommitted in
            isCommitted
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onTap()
        }
        .accessibilityAction(named: Text("Edit")) {
            onEdit()
        }
        .accessibilityAction(named: Text("Delete")) {
            onDelete()
        }
    }

    /// What the swipe is heading towards, sitting still behind the moving row.
    /// It is decoration and never touched: the swipe itself is the action, so
    /// there is nothing here to tap.
    ///
    /// Until the row has been carried far enough, the colour is held back and
    /// the mark is small: letting go here would do nothing, and the background
    /// should not promise otherwise. Crossing the distance fills the colour in
    /// and swells the mark, and the phone says so under the finger.
    @ViewBuilder
    private var background: some View {
        if let action = motion.aimedAction {
            HStack(spacing: 0) {
                if action == .edit {
                    Spacer(minLength: 0)
                }

                icon(for: action)
                    .frame(width: TransactionSwipeAction.commitDistance)

                if action == .delete {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tint(for: action).opacity(motion.isCommitted ? 1 : 0.45))
            .animation(.snappy(duration: 0.2), value: motion.isCommitted)
            .accessibilityHidden(true)
        }
    }

    private func icon(for action: TransactionSwipeAction) -> some View {
        VStack(spacing: 6) {
            Image(systemName: action == .delete ? "trash.fill" : "pencil")
                .font(.body.weight(.bold))

            Text(action == .delete ? "Delete" : "Edit")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .scaleEffect(motion.isCommitted ? 1 : 0.82)
    }

    private func tint(for action: TransactionSwipeAction) -> Color {
        action == .delete ? MonMonTheme.danger : MonMonTheme.accent
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
                let released = motion.dragging(value.translation)

                arbiter?.release()

                withAnimation(.snappy(duration: 0.25)) {
                    motion = TransactionSwipeMotion()
                }

                switch released.committedAction {
                case .delete:
                    onDelete()
                case .edit:
                    onEdit()
                case nil:
                    break
                }
            }
    }
}
