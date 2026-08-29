import SwiftUI

struct BudgetIncomeCard: View {
    let snapshot: BudgetSnapshot
    let monthTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(monthTitle, systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Available to plan")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(VNDCurrency.format(snapshot.projectedIncome))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }

            HStack(alignment: .top, spacing: 20) {
                incomeMetric("Planned", amount: snapshot.plannedIncome)
                incomeMetric("Received", amount: snapshot.receivedIncome)
            }

            if snapshot.unallocatedPercent > 0 {
                Label(
                    "\(PercentInput.format(snapshot.unallocatedPercent))% is not allocated yet",
                    systemImage: "exclamationmark.circle.fill"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(MonMonTheme.textSecondary)
                .accessibilityIdentifier("budget-unallocated")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(MonMonTheme.hero, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(MonMonTheme.heroBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("budget-income-summary")
    }

    private func incomeMetric(_ title: LocalizedStringKey, amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MonMonTheme.textMuted)

            Text(VNDCurrency.format(amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BudgetJarCard: View {
    let row: BudgetJarSnapshot

    private var tint: Color {
        CategoryPalette.color(named: row.colorName)
    }

    private var progress: Double {
        guard row.projected > 0 else {
            return 0
        }
        return min(max(NSDecimalNumber(decimal: row.used / row.projected).doubleValue, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: CategoryPalette.symbolName(row.symbolName))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 11))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(.headline)

                    Text("\(PercentInput.format(row.allocationPercent))% allocation")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                Spacer(minLength: 8)

                if row.role != .custom {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textMuted)
                        .accessibilityLabel("System jar")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(row.remaining >= 0 ? "Left this month" : "Over budget")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(VNDCurrency.format(row.remaining))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(
                        row.remaining >= 0 ? MonMonTheme.textPrimary : MonMonTheme.danger
                    )
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }

            ProgressView(value: progress)
                .tint(row.remaining >= 0 ? tint : MonMonTheme.danger)
                .accessibilityLabel("Budget used")
                .accessibilityValue(Percentage.label(of: row.used, in: row.projected))

            HStack(alignment: .top, spacing: 12) {
                metric("Plan", amount: row.planned)
                metric("Available", amount: row.projected)
                metric("Used", amount: row.used)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("budget-jar-\(row.jarID.uuidString)")
    }

    private func metric(_ title: LocalizedStringKey, amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MonMonTheme.textMuted)

            Text(VNDCurrency.format(amount))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
