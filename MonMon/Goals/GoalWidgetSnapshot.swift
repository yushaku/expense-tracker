import Foundation

/// A read-only projection of earmarked money, never a second balance.
struct GoalWidgetSnapshot: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let targetAmount: Decimal
    let earmarkedAmount: Decimal
    let symbolName: String
    let colorName: String
    let isArchived: Bool

    var remainingAmount: Decimal { max(0, targetAmount - earmarkedAmount) }
    var isComplete: Bool { targetAmount > 0 && remainingAmount == 0 }
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1, max(0, NSDecimalNumber(decimal: earmarkedAmount / targetAmount).doubleValue))
    }
    var nextMilestonePercent: Int? {
        guard targetAmount > 0, !isComplete else { return nil }
        return [25, 50, 75, 100].first {
            earmarkedAmount < targetAmount * Decimal($0) / 100
        }
    }
    var amountToNextMilestone: Decimal? {
        guard let percent = nextMilestonePercent else { return nil }
        return max(0, targetAmount * Decimal(percent) / 100 - earmarkedAmount)
    }
}

struct GoalWidgetStore {
    static let kind = "SavingsGoalWidget"
    static let storageKey = "savingsGoalWidgetSnapshots"
    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? QuickExpenseWidgetConfiguration.makeDefaults()
    }

    func load() -> [GoalWidgetSnapshot] {
        guard let data = defaults.data(forKey: Self.storageKey),
            let snapshots = try? JSONDecoder().decode([GoalWidgetSnapshot].self, from: data)
        else { return [] }
        return snapshots
    }

    @discardableResult
    func save(_ snapshots: [GoalWidgetSnapshot]) throws -> Bool {
        guard load() != snapshots || defaults.data(forKey: Self.storageKey) == nil else {
            return false
        }
        defaults.set(try JSONEncoder().encode(snapshots), forKey: Self.storageKey)
        return true
    }

    /// An explicit selection never silently switches to a different goal.
    func selected(id: UUID?) -> GoalWidgetSnapshot? {
        guard let id else { return nil }
        return load().first { $0.id == id && !$0.isArchived }
    }
}

#if !WIDGET_EXTENSION
    import SwiftData
    import WidgetKit

    extension GoalWidgetSnapshot {
        @MainActor
        static func make(in context: ModelContext) throws -> [Self] {
            try context.fetch(
                FetchDescriptor<FinancialGoal>(
                    sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)]
                )
            ).map {
                Self(
                    id: $0.id, name: $0.name, targetAmount: $0.targetAmount,
                    earmarkedAmount: $0.earmarkedAmount, symbolName: $0.symbolName,
                    colorName: $0.colorName, isArchived: $0.archivedAt != nil)
            }
        }

        @MainActor
        static func refresh(in context: ModelContext) {
            guard !MonMonProcess.isRunningUnitTests else { return }
            do {
                if try GoalWidgetStore().save(make(in: context)) {
                    WidgetCenter.shared.reloadTimelines(ofKind: GoalWidgetStore.kind)
                }
            } catch {
                // Retry on the next save or activation without failing a ledger save.
            }
        }
    }
#endif
