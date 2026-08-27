import SwiftUI

#if os(iOS)
    import UIKit
#endif

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

    /// A row only owns movement that is already clearly horizontal. Returning
    /// false lets the enclosing scroll view's pan recognizer take a vertical
    /// drag, matching the gesture arbitration of native list swipe actions.
    static func shouldCaptureSwipe(moving movement: CGSize) -> Bool {
        horizontalTranslation(in: movement) != nil
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

    /// How far the finger carries the row before letting go acts on it. Far
    /// enough past a hesitant nudge to be meant, and near enough that a thumb
    /// reaches it without stretching across the card.
    static let commitDistance: CGFloat = 76

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

#if os(iOS)
    /// Bridges the row swipe to UIKit so a vertical pan can fail before it takes
    /// the touch away from the enclosing SwiftUI `ScrollView`.
    private struct TransactionHorizontalSwipeGesture: UIGestureRecognizerRepresentable {
        let onChanged: (CGSize) -> Void
        let onEnded: (CGSize) -> Void

        func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
            Coordinator()
        }

        func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
            let recognizer = UIPanGestureRecognizer()
            recognizer.delegate = context.coordinator
            return recognizer
        }

        func handleUIGestureRecognizerAction(
            _ recognizer: UIPanGestureRecognizer,
            context _: Context
        ) {
            let point = recognizer.translation(in: recognizer.view)
            let translation = CGSize(width: point.x, height: point.y)

            switch recognizer.state {
            case .began, .changed:
                onChanged(translation)
            case .ended:
                onEnded(translation)
            case .cancelled, .failed:
                onEnded(.zero)
            case .possible:
                break
            @unknown default:
                onEnded(.zero)
            }
        }

        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
            func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
                guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
                    return false
                }

                let velocity = pan.velocity(in: pan.view)
                return TransactionRowGestureIntent.shouldCaptureSwipe(
                    moving: CGSize(width: velocity.x, height: velocity.y)
                )
            }
        }
    }
#endif

/// Swipe actions for a card inside a `ScrollView`, where SwiftUI's native
/// `swipeActions` modifier does not provide list-row behaviour.
struct TransactionSwipeRow<Content: View>: View {
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let content: Content

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

            interactiveContent
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

    @ViewBuilder
    private var interactiveContent: some View {
        #if os(iOS)
            content
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .gesture(
                    TransactionHorizontalSwipeGesture(
                        onChanged: updateSwipe,
                        onEnded: finishSwipe
                    )
                )
                .offset(x: motion.displayedOffset)
        #else
            content
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .simultaneousGesture(rowGesture)
                .offset(x: motion.displayedOffset)
        #endif
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
                updateSwipe(value.translation)
            }
            .onEnded { value in
                finishSwipe(value.translation)
            }
    }

    private func updateSwipe(_ translation: CGSize) {
        let moved = motion.dragging(translation)

        // A drag reports every frame, and most of those frames leave the row
        // exactly where it was. Avoid rebuilding it when nothing changed.
        if moved != motion {
            motion = moved
        }
    }

    private func finishSwipe(_ translation: CGSize) {
        let released = motion.dragging(translation)

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
