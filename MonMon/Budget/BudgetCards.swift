import Charts
import SwiftUI

struct BudgetIncomeCard: View {
    let snapshot: BudgetSnapshot
    let monthTitle: String
    let onOpenTimeline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Label(monthTitle, systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textSecondary)

                Spacer(minLength: 8)

                Button(action: onOpenTimeline) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(MonMonTheme.accent.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Income history")
                .accessibilityIdentifier("budget-income-history")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Available to plan")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(VNDCurrency.format(snapshot.projectedIncome))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }

            BudgetAllocationOverview(snapshot: snapshot)

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
        .accessibilityElement(children: .contain)
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

private struct BudgetAllocationOverview: View {
    @Environment(\.locale) private var locale

    let snapshot: BudgetSnapshot

    private static let diameter: CGFloat = 168

    private var allocatedPercent: Decimal {
        min(max(snapshot.allocationPercent, 0), 100)
    }

    private var chartRows: [BudgetJarSnapshot] {
        snapshot.rows.filter { $0.allocationPercent > 0 }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) {
                doughnut
                legend
            }

            VStack(spacing: 18) {
                doughnut
                legend
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Budget allocation")
    }

    private var doughnut: some View {
        Chart {
            ForEach(chartRows) { row in
                SectorMark(
                    angle: .value(
                        "Allocation percentage",
                        chartValue(row.allocationPercent)
                    ),
                    innerRadius: .ratio(0.62),
                    outerRadius: .ratio(0.9),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(CategoryPalette.color(named: row.colorName))
            }

            if snapshot.unallocatedPercent > 0 {
                SectorMark(
                    angle: .value(
                        "Unallocated percentage",
                        chartValue(snapshot.unallocatedPercent)
                    ),
                    innerRadius: .ratio(0.62),
                    outerRadius: .ratio(0.9),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(MonMonTheme.textMuted.opacity(0.42))
            }
        }
        .chartLegend(.hidden)
        .frame(width: Self.diameter, height: Self.diameter)
        .overlay {
            VStack(spacing: 2) {
                Text("ALLOCATED")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text("\(PercentInput.format(allocatedPercent))%")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)
        }
        // The rows beside or below the chart carry the same information in text.
        .accessibilityHidden(true)
    }

    private var legend: some View {
        VStack(spacing: 10) {
            ForEach(snapshot.rows) { row in
                legendRow(
                    name: row.name,
                    percent: row.allocationPercent,
                    color: CategoryPalette.color(named: row.colorName)
                )
            }

            if snapshot.unallocatedPercent > 0 {
                legendRow(
                    name: AppText.string("Unallocated", in: locale),
                    percent: snapshot.unallocatedPercent,
                    color: MonMonTheme.textMuted.opacity(0.42)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(name: String, percent: Decimal, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            Text(name)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(PercentInput.format(percent))%")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func chartValue(_ percent: Decimal) -> Double {
        NSDecimalNumber(decimal: percent).doubleValue
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
                metric("Actual", amount: row.received)
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
