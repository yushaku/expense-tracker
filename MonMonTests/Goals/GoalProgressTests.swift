import Foundation
import Testing

@testable import MonMon

@Suite("Goal progress")
struct GoalProgressTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test("Required monthly contribution uses every month through the target")
    func requiredMonthlyUsesMonthsThroughTarget() {
        let goal = makeGoal(
            targetAmount: 1_000,
            earmarkedAmount: 100,
            targetDate: date(2027, 3, 31),
            monthlyContribution: 300
        )

        let snapshot = GoalProgress.snapshot(
            goal: goal,
            asOf: date(2027, 1, 15),
            calendar: calendar
        )

        #expect(snapshot.remainingAmount == 900)
        #expect(snapshot.requiredMonthlyContribution == 300)
        #expect(snapshot.forecastCompletionDate == date(2027, 3, 31))
        #expect(snapshot.progress == 0.1)
    }

    @Test("Required monthly contribution rounds up to a whole dong")
    func requiredMonthlyRoundsUp() {
        let goal = makeGoal(
            targetAmount: 1_000,
            earmarkedAmount: 1,
            targetDate: date(2027, 2, 28),
            monthlyContribution: 0
        )

        let snapshot = GoalProgress.snapshot(
            goal: goal,
            asOf: date(2027, 1, 15),
            calendar: calendar
        )

        #expect(snapshot.requiredMonthlyContribution == 500)
        #expect(snapshot.forecastCompletionDate == nil)
    }

    @Test("A completed goal has no remainder and completes now")
    func completedGoalCompletesNow() {
        let asOf = date(2027, 1, 15)
        let goal = makeGoal(
            targetAmount: 1_000,
            earmarkedAmount: 1_000,
            targetDate: date(2027, 12, 31),
            monthlyContribution: 100
        )

        let snapshot = GoalProgress.snapshot(goal: goal, asOf: asOf, calendar: calendar)

        #expect(snapshot.isComplete)
        #expect(snapshot.remainingAmount == 0)
        #expect(snapshot.requiredMonthlyContribution == 0)
        #expect(snapshot.forecastCompletionDate == asOf)
        #expect(snapshot.progress == 1)
    }

    private func makeGoal(
        targetAmount: Decimal,
        earmarkedAmount: Decimal,
        targetDate: Date,
        monthlyContribution: Decimal
    ) -> FinancialGoal {
        FinancialGoal(
            id: UUID(),
            name: "Home",
            kind: .home,
            targetAmount: targetAmount,
            earmarkedAmount: earmarkedAmount,
            targetDate: targetDate,
            monthlyContribution: monthlyContribution,
            fundingJarID: BudgetJarSeed.savingsID,
            symbolName: "house.fill",
            colorName: "blue",
            createdAt: date(2027, 1, 1)
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        guard
            let date = calendar.date(
                from: DateComponents(year: year, month: month, day: day))
        else {
            preconditionFailure("Invalid test date")
        }
        return date
    }
}
