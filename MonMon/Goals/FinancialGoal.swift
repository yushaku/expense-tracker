import Foundation
import SwiftData

/// An earmark inside a budget jar, not a second financial balance.
@Model
final class FinancialGoal {
    var id: UUID = UUID()
    var name: String = ""
    var targetAmount: Decimal = Decimal.zero
    var earmarkedAmount: Decimal = Decimal.zero
    var targetDate: Date = Date(timeIntervalSince1970: 0)
    var monthlyContribution: Decimal = Decimal.zero
    var fundingJarID: UUID?
    var symbolName: String = CategoryPalette.defaultSymbolName
    var colorName: String = CategoryPalette.defaultColorName
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var contributionHistoryData: Data?
    var archivedAt: Date?

    init(
        id: UUID,
        name: String,
        targetAmount: Decimal,
        earmarkedAmount: Decimal,
        targetDate: Date,
        monthlyContribution: Decimal,
        fundingJarID: UUID?,
        symbolName: String,
        colorName: String,
        createdAt: Date,
        contributionHistoryData: Data? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.earmarkedAmount = earmarkedAmount
        self.targetDate = targetDate
        self.monthlyContribution = monthlyContribution
        self.fundingJarID = fundingJarID
        self.symbolName = CategoryPalette.symbolName(symbolName)
        self.colorName = CategoryPalette.colorName(colorName)
        self.createdAt = createdAt
        self.contributionHistoryData = contributionHistoryData
        self.archivedAt = archivedAt
    }
}

enum GoalArchiveError: Error, Equatable {
    case goalIsIncomplete
}

enum GoalArchive {
    static func archive(_ goal: FinancialGoal, at date: Date) throws {
        guard goal.earmarkedAmount >= goal.targetAmount else {
            throw GoalArchiveError.goalIsIncomplete
        }
        goal.archivedAt = date
    }

    static func restore(_ goal: FinancialGoal) {
        goal.archivedAt = nil
    }
}

struct GoalContribution: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let amount: Decimal
    let occurredAt: Date
}

enum GoalContributionError: Error, Equatable {
    case nonPositiveAmount
    case exceedsRemaining
    case invalidHistory
}

enum GoalContributionStore {
    static func entries(for goal: FinancialGoal) -> [GoalContribution] {
        (try? decodedEntries(for: goal)) ?? []
    }

    static func validatedEntries(for goal: FinancialGoal) throws -> [GoalContribution] {
        try decodedEntries(for: goal)
    }

    static func record(
        amount: Decimal,
        on goal: FinancialGoal,
        id: UUID,
        occurredAt: Date
    ) throws {
        guard amount > 0 else {
            throw GoalContributionError.nonPositiveAmount
        }
        guard amount <= max(0, goal.targetAmount - goal.earmarkedAmount) else {
            throw GoalContributionError.exceedsRemaining
        }

        var entries = try decodedEntries(for: goal)
        entries.append(GoalContribution(id: id, amount: amount, occurredAt: occurredAt))
        entries.sort {
            if $0.occurredAt == $1.occurredAt {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.occurredAt < $1.occurredAt
        }

        goal.contributionHistoryData = try JSONEncoder().encode(entries)
        goal.earmarkedAmount += amount
    }

    static func replace(
        entries: [GoalContribution],
        on goal: FinancialGoal
    ) throws {
        goal.contributionHistoryData = entries.isEmpty ? nil : try JSONEncoder().encode(entries)
    }

    private static func decodedEntries(for goal: FinancialGoal) throws -> [GoalContribution] {
        guard let data = goal.contributionHistoryData else {
            return []
        }
        do {
            return try JSONDecoder().decode([GoalContribution].self, from: data)
        } catch {
            throw GoalContributionError.invalidHistory
        }
    }
}
