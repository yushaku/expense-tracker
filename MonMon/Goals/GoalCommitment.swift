import Foundation

struct GoalCommitmentSnapshot: Equatable {
    let goalCount: Int
    let committedAmount: Decimal
    let plannedCapacity: Decimal

    var availableAmount: Decimal {
        max(0, plannedCapacity - committedAmount)
    }

    var overcommittedAmount: Decimal {
        max(0, committedAmount - plannedCapacity)
    }

    var isOvercommitted: Bool {
        overcommittedAmount > 0
    }
}

enum GoalCommitment {
    static func snapshots(
        jarIDs: [UUID],
        goals: [FinancialGoal],
        capacityByJar: [UUID: Decimal]
    ) -> [UUID: GoalCommitmentSnapshot] {
        Dictionary(
            uniqueKeysWithValues: jarIDs.map { jarID in
                (
                    jarID,
                    snapshot(
                        jarID: jarID,
                        goals: goals,
                        plannedCapacity: capacityByJar[jarID, default: .zero]
                    )
                )
            }
        )
    }

    static func snapshot(
        jarID: UUID,
        goals: [FinancialGoal],
        plannedCapacity: Decimal
    ) -> GoalCommitmentSnapshot {
        let activeGoals = goals.filter {
            $0.fundingJarID == jarID && activeMonthlyContribution(for: $0) > 0
        }
        return GoalCommitmentSnapshot(
            goalCount: activeGoals.count,
            committedAmount: activeGoals.reduce(Decimal.zero) {
                $0 + activeMonthlyContribution(for: $1)
            },
            plannedCapacity: max(0, plannedCapacity)
        )
    }

    static func activeMonthlyContribution(for goal: FinancialGoal) -> Decimal {
        goal.archivedAt == nil && goal.earmarkedAmount < goal.targetAmount
            ? max(0, goal.monthlyContribution) : 0
    }

    static func activeMonthlyContribution(
        targetAmount: Decimal,
        earmarkedAmount: Decimal,
        monthlyContribution: Decimal
    ) -> Decimal {
        earmarkedAmount < targetAmount ? max(0, monthlyContribution) : 0
    }
}
