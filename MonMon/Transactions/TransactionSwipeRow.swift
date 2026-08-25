import SwiftUI

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

/// Swipe actions for a card inside a `ScrollView`, where SwiftUI's native
/// `swipeActions` modifier does not provide list-row behaviour.
struct TransactionSwipeRow<Content: View>: View {
    let onEdit: () -> Void
    let onDelete: () -> Void
    let content: Content

    @State private var reveal = TransactionSwipeReveal.none
    @GestureState private var dragTranslation = CGSize.zero

    init(
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack {
            actions

            content
                .offset(x: displayedOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .simultaneousGesture(swipeGesture)
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
                isAccessible: reveal == .delete
            ) {
                perform(onDelete)
            }

            Spacer(minLength: 0)

            actionButton(
                title: "Edit",
                systemImage: "pencil",
                tint: MonMonTheme.accent,
                isAccessible: reveal == .edit
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

    private var displayedOffset: CGFloat {
        let horizontalDrag =
            TransactionSwipeReveal.horizontalTranslation(in: dragTranslation) ?? 0

        return min(
            TransactionSwipeReveal.actionWidth,
            max(-TransactionSwipeReveal.actionWidth, reveal.offset + horizontalDrag)
        )
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in
                guard
                    let horizontalTranslation = TransactionSwipeReveal.horizontalTranslation(
                        in: value.translation
                    )
                else {
                    return
                }

                state = CGSize(width: horizontalTranslation, height: value.translation.height)
            }
            .onEnded { value in
                withAnimation(.snappy(duration: 0.25)) {
                    reveal = TransactionSwipeReveal.resolved(
                        after: value.translation,
                        from: reveal
                    )
                }
            }
    }

    private func perform(_ action: () -> Void) {
        withAnimation(.snappy(duration: 0.2)) {
            reveal = .none
        }
        action()
    }
}
