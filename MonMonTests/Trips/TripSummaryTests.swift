import Foundation
import Testing

@testable import MonMon

@Suite("Trip summary")
struct TripSummaryTests {
    private let tripID = UUID()
    private let occurredAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Only linked expenses reduce the Trip budget and retain category detail")
    func linkedExpensesBuildSummary() throws {
        let food = category(name: "Food")
        let hotel = category(name: "Accommodation")
        let workspace = trip(budget: 10_000_000)
        let newest = transaction(amount: 3_000_000, categoryID: hotel.id, offset: 2)
        let transactions = [
            transaction(amount: 1_000_000, categoryID: food.id, offset: 0),
            transaction(amount: 2_000_000, categoryID: food.id, offset: 1),
            newest,
            transaction(amount: 9_000_000, categoryID: food.id, tripID: UUID(), offset: 3),
            transaction(
                kind: .income, amount: 20_000_000, categoryID: nil, tripID: tripID, offset: 4),
        ]

        let snapshot = TripSummary.snapshot(
            workspace: workspace,
            transactions: transactions,
            categories: [food, hotel]
        )

        #expect(snapshot.budgetAmount == 10_000_000)
        #expect(snapshot.spentAmount == 6_000_000)
        #expect(snapshot.remainingAmount == 4_000_000)
        #expect(snapshot.overBudgetAmount == 0)
        #expect(
            snapshot.linkedTransactionIDs == [newest.id, transactions[1].id, transactions[0].id])
        #expect(snapshot.categoryBreakdown.map(\.name) == ["Accommodation", "Food"])
        #expect(snapshot.categoryBreakdown.map(\.amount) == [3_000_000, 3_000_000])
        #expect(snapshot.categoryBreakdown.map(\.count) == [1, 2])
    }

    @Test("Overspending is explicit and a deleted category remains counted")
    func overBudgetAndUncategorizedRemainVisible() {
        let workspace = trip(budget: 5_000_000)
        let transaction = transaction(amount: 6_500_000, categoryID: UUID(), offset: 0)

        let snapshot = TripSummary.snapshot(
            workspace: workspace,
            transactions: [transaction],
            categories: []
        )

        #expect(snapshot.spentAmount == 6_500_000)
        #expect(snapshot.remainingAmount == 0)
        #expect(snapshot.overBudgetAmount == 1_500_000)
        #expect(snapshot.categoryBreakdown.first?.name == CategoryBreakdown.uncategorizedName)
        #expect(snapshot.categoryBreakdown.first?.amount == 6_500_000)
    }

    private func trip(budget: Decimal) -> TripWorkspace {
        TripWorkspace(
            id: tripID,
            sourceGoalID: UUID(),
            name: "Da Nang",
            budgetAmount: budget,
            fundingJarID: BudgetJarSeed.savingsID,
            symbolName: "airplane",
            colorName: "sky",
            status: .active,
            startedAt: occurredAt,
            completedAt: nil,
            createdAt: occurredAt
        )
    }

    private func category(name: String) -> TransactionCategory {
        TransactionCategory(
            id: UUID(),
            name: name,
            kind: .expense,
            symbolName: "tag.fill",
            colorName: "green",
            createdAt: occurredAt
        )
    }

    private func transaction(
        kind: TransactionKind = .expense,
        amount: Decimal,
        categoryID: UUID?,
        tripID: UUID? = nil,
        offset: TimeInterval
    ) -> MoneyTransaction {
        MoneyTransaction(
            id: UUID(),
            kind: kind,
            amount: amount,
            occurredAt: occurredAt.addingTimeInterval(offset),
            note: "",
            accountID: UUID(),
            categoryID: categoryID,
            sourceRuleID: nil,
            currencyCode: VNDCurrency.code,
            createdAt: occurredAt,
            tripWorkspaceID: tripID ?? self.tripID
        )
    }
}
