import SwiftData

/// The one save path for ordinary writes to the financial store.
///
/// A plain `ModelContext.save()` followed by the widget refreshes every write
/// owes: the goal and today-expense widgets read snapshots this app publishes,
/// so a save that skipped them would leave a widget showing yesterday's figure.
@MainActor
enum StoreWrite {
    static func save(_ context: ModelContext) throws {
        try context.save()
        GoalWidgetSnapshot.refresh(in: context)
        WidgetTodayExpenses.refresh(in: context)
    }
}
