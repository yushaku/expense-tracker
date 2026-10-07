import SwiftUI

/// One interaction rule for every sheet the app owns. Sheet dismissal gets the
/// first claim on a swipe so a scroll view cannot bounce before the sheet moves.
enum AppSheetPresentation {
    static let contentInteraction = PresentationContentInteraction.resizes
}

extension View {
    func appSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .presentationContentInteraction(AppSheetPresentation.contentInteraction)
                .modifier(SyncEditingSheet())
        }
    }

    func appSheet<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { item in
            content(item)
                .presentationContentInteraction(AppSheetPresentation.contentInteraction)
                .modifier(SyncEditingSheet())
        }
    }
}

/// Keep draft forms alive while automatic sync is waiting to refresh model-backed views.
private struct SyncEditingSheet: ViewModifier {
    @Environment(SyncCoordinator.self) private var sync: SyncCoordinator?
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { sync?.setEditing(true, token: token) }
            .onDisappear { sync?.setEditing(false, token: token) }
    }
}
