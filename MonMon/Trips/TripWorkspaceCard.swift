import SwiftUI

struct TripWorkspaceCard: View {
    let workspace: TripWorkspace
    let snapshot: TripSummarySnapshot

    private var tint: Color {
        CategoryPalette.color(named: workspace.colorName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TripCardHeader(
                name: workspace.name,
                subtitle: workspace.status == .active
                    ? Text("Active trip") : Text("Completed trip"),
                symbolName: workspace.symbolName,
                tint: tint,
                status: workspace.status == .active ? "Active" : "Completed"
            )

            ProgressView(value: progress)
                .tint(snapshot.overBudgetAmount > 0 ? MonMonTheme.danger : tint)
                .accessibilityLabel("Trip budget used")
                .accessibilityValue(
                    Percentage.label(of: snapshot.spentAmount, in: snapshot.budgetAmount))

            HStack(alignment: .top, spacing: 12) {
                TripMetric(title: "Budget", amount: snapshot.budgetAmount)
                TripMetric(title: "Spent", amount: snapshot.spentAmount)
                TripMetric(
                    title: snapshot.overBudgetAmount > 0 ? "Over budget" : "Left to spend",
                    amount: snapshot.overBudgetAmount > 0
                        ? snapshot.overBudgetAmount : snapshot.remainingAmount,
                    isWarning: snapshot.overBudgetAmount > 0
                )
            }
        }
        .tripCardStyle()
        .accessibilityElement(children: .contain)
    }

    private var progress: Double {
        guard snapshot.budgetAmount > 0 else {
            return 0
        }
        return min(
            1,
            NSDecimalNumber(decimal: snapshot.spentAmount / snapshot.budgetAmount).doubleValue
        )
    }
}

private struct TripCardHeader: View {
    let name: String
    let subtitle: Text
    let symbolName: String
    let tint: Color
    let status: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: CategoryPalette.symbolName(symbolName))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)

                subtitle
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(status)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(tint.opacity(0.14), in: Capsule())
        }
    }
}

struct TripMetric: View {
    let title: LocalizedStringKey
    let amount: Decimal
    var isWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(MonMonTheme.textMuted)

            Text(VNDCurrency.format(amount))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isWarning ? MonMonTheme.danger : MonMonTheme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TripCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
    }
}

extension View {
    fileprivate func tripCardStyle() -> some View {
        modifier(TripCardStyle())
    }
}
