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
        let transaction = transaction(
            amount: 6_500_000,
            categoryID: UUID(),
            tripID: workspace.id,
            offset: 0
        )

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

    @Test("Trip collection separates funded goals, active trips, and completed trips")
    func collectionSeparatesLifecycleStages() {
        let fullyFunded = goal(name: "Fully funded", earmarked: 10_000_000)
        let partiallyFunded = goal(name: "Partially funded", earmarked: 4_000_000)
        let jarless = goal(name: "No jar", earmarked: 10_000_000)
        jarless.fundingJarID = nil
        let alreadyStarted = goal(name: "Started", earmarked: 10_000_000)
        let active = trip(budget: 10_000_000, sourceGoalID: alreadyStarted.id)
        let completed = trip(
            budget: 5_000_000,
            sourceGoalID: UUID(),
            status: .completed
        )

        let collection = TripWorkspaceCollection.snapshot(
            goals: [partiallyFunded, fullyFunded, jarless, alreadyStarted],
            workspaces: [completed, active]
        )

        #expect(collection.usableGoalIDs == [partiallyFunded.id, fullyFunded.id])
        #expect(collection.activeWorkspaceIDs == [active.id])
        #expect(collection.completedWorkspaceIDs == [completed.id])
    }

    @Test("Selecting a Trip defaults its jar and detaching clears Trip routing")
    func transactionSelectionDefaultsAndClearsRouting() {
        let active = trip(budget: 10_000_000)
        let completed = trip(budget: 5_000_000, status: .completed)
        var draft = TransactionDraft(
            kind: .expense,
            amountText: "100000",
            occurredAt: occurredAt,
            accountID: UUID(),
            categoryID: UUID()
        )

        TripTransactionSelection.apply(
            workspaceID: active.id,
            workspaces: [completed, active],
            to: &draft
        )

        #expect(draft.tripWorkspaceID == active.id)
        #expect(draft.budgetJarOverrideID == active.fundingJarID)
        #expect(
            TripTransactionSelection.availableWorkspaces(
                [completed, active],
                selectedID: completed.id
            ).map(\.id) == [active.id, completed.id]
        )

        TripTransactionSelection.apply(
            workspaceID: nil,
            workspaces: [completed, active],
            to: &draft
        )
        #expect(draft.tripWorkspaceID == nil)
        #expect(draft.budgetJarOverrideID == nil)
    }

    private func trip(
        budget: Decimal,
        sourceGoalID: UUID = UUID(),
        status: TripWorkspaceStatus = .active
    ) -> TripWorkspace {
        TripWorkspace(
            id: status == .active && budget == 10_000_000 ? tripID : UUID(),
            sourceGoalID: sourceGoalID,
            name: "Da Nang",
            budgetAmount: budget,
            fundingJarID: BudgetJarSeed.savingsID,
            symbolName: "airplane",
            colorName: "sky",
            status: status,
            startedAt: occurredAt,
            completedAt: status == .completed ? occurredAt : nil,
            createdAt: occurredAt
        )
    }

    private func goal(name: String, earmarked: Decimal) -> FinancialGoal {
        FinancialGoal(
            id: UUID(),
            name: name,
            kind: .custom,
            targetAmount: 10_000_000,
            earmarkedAmount: earmarked,
            targetDate: occurredAt,
            monthlyContribution: 1_000_000,
            fundingJarID: BudgetJarSeed.savingsID,
            symbolName: "airplane",
            colorName: "sky",
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
