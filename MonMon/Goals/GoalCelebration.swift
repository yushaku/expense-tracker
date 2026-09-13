import SwiftData
import SwiftUI

/// Completion is emitted only by a successful local contribution save. Opening
/// an already complete goal or applying a sync snapshot never replays it.
@MainActor
enum GoalContributionCommit {
    static func save(
        amount: Decimal, goal: FinancialGoal, occurredAt: Date,
        in context: ModelContext
    ) throws -> Bool {
        let originalAmount = goal.earmarkedAmount
        let originalHistory = goal.contributionHistoryData
        let wasIncomplete = goal.earmarkedAmount < goal.targetAmount
        do {
            try GoalContributionStore.record(
                amount: amount, on: goal, id: UUID(), occurredAt: occurredAt)
            try SyncWriteGate.save(context)
            return wasIncomplete && goal.targetAmount > 0
                && goal.earmarkedAmount >= goal.targetAmount
        } catch {
            context.rollback()
            // Restore cached values as well as the persisted transaction.
            goal.earmarkedAmount = originalAmount
            goal.contributionHistoryData = originalHistory
            throw error
        }
    }
}

struct GoalCelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let goalName: String
    let onFinished: () -> Void
    @State private var appeared = false
    @State private var lifted = false
    @State private var burst = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if !reduceMotion {
                    ForEach(0..<18, id: \.self) { index in
                        Capsule()
                            .fill(confettiColor(index))
                            .frame(width: 5, height: 10)
                            .rotationEffect(.degrees(Double(index * 37)))
                            .offset(
                                x: burst ? cos(Double(index) * .pi / 9) * 125 : 0,
                                y: burst ? sin(Double(index) * .pi / 9) * 100 : 0
                            )
                            .opacity(burst ? 0 : 1)
                            .animation(.easeOut(duration: 1.5), value: burst)
                            .accessibilityHidden(true)
                    }
                }
                Image("MonMonCat")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .offset(y: reduceMotion ? 0 : (lifted ? -14 : 0))
                    .rotationEffect(.degrees(reduceMotion ? 0 : (lifted ? -4 : 0)))
                    .accessibilityHidden(true)
            }
            .frame(height: 174)
            Text("You reached your goal!")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(goalName)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .padding(20)
        .frame(maxWidth: 300)
        .background(MonMonTheme.surface, in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24).stroke(MonMonTheme.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .padding(24)
        .opacity(appeared ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: appeared)
        .sensoryFeedback(.success, trigger: appeared) { _, newValue in newValue && !reduceMotion }
        .accessibilityElement(children: .combine)
        .task {
            appeared = true
            burst = true
            if !reduceMotion {
                withAnimation(.spring(duration: 0.45).repeatCount(2, autoreverses: true)) {
                    lifted = true
                }
            }
            do {
                try await Task.sleep(for: .seconds(1.8))
                appeared = false
                try await Task.sleep(for: .milliseconds(200))
                onFinished()
            } catch {
                // Leaving the screen cancels the animation's lifetime.
            }
        }
    }

    private func confettiColor(_ index: Int) -> Color {
        let colors = [
            MonMonTheme.accent, MonMonTheme.Hue.mauve, MonMonTheme.Hue.peach,
            MonMonTheme.Hue.yellow, MonMonTheme.Hue.sky,
        ]
        return colors[index % colors.count]
    }
}
