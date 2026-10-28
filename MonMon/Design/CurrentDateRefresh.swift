import Combine
import SwiftUI

extension View {
    /// Keeps a stored "today" current for a screen that reads the clock.
    ///
    /// A `Date` taken once in `init` goes stale after midnight or into a new
    /// month while the screen stays alive, and a `.now` default argument hands
    /// every rebuild of the parent a different date. Storing it in `@State`
    /// and refreshing it here, when the view appears, when the app returns to
    /// the foreground and when the calendar day changes, avoids both.
    func refreshesCurrentDate(_ date: Binding<Date>) -> some View {
        modifier(CurrentDateRefresh(date: date))
    }
}

private struct CurrentDateRefresh: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var date: Date

    func body(content: Content) -> some View {
        content
            .onAppear { date = .now }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    date = .now
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
                    .receive(on: RunLoop.main)
            ) { _ in
                date = .now
            }
    }
}
