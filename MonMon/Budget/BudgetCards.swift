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

    private var allocatedPercent: Decimal {
        min(max(snapshot.allocationPercent, 0), 100)
    }

    private var items: [AllocationDoughnutItem] {
        var result = snapshot.rowsByAllocation.map { row in
            AllocationDoughnutItem(
                id: row.jarID.uuidString,
                name: row.name,
                amount: row.allocationPercent,
                tint: CategoryPalette.color(named: row.colorName),
                symbolName: CategoryPalette.symbolName(row.symbolName),
                valueLabel: VNDCurrency.format(row.projected)
            )
        }

        if snapshot.unallocatedPercent > 0 {
            let allocatedAmount = snapshot.rows.reduce(Decimal.zero) { $0 + $1.projected }
            result.append(
                AllocationDoughnutItem(
                    id: "unallocated",
                    name: AppText.string("Unallocated", in: locale),
                    amount: snapshot.unallocatedPercent,
                    tint: MonMonTheme.textMuted.opacity(0.42),
                    symbolName: "circle.dashed",
                    valueLabel: VNDCurrency.format(
                        max(0, snapshot.projectedIncome - allocatedAmount)
                    )
                )
            )
        }

        return result
    }

    var body: some View {
        AllocationDoughnut(
            context: AppText.string("Budget allocation", in: locale),
            items: items,
            totalLabel: "Allocated",
            totalValueLabel: "\(PercentInput.format(allocatedPercent))%"
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Budget allocation")
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
                    HStack(spacing: 6) {
                        Text(row.name)
                            .font(.headline)
                            .lineLimit(1)

                        if row.role != .custom {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(MonMonTheme.textMuted)
                                .accessibilityLabel("System jar")
                        }
                    }

                    Text("\(PercentInput.format(row.allocationPercent))% allocation")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Image(
                        systemName: row.remaining >= 0
                            ? "calendar" : "exclamationmark.triangle.fill"
                    )
                    .accessibilityHidden(true)

                    Text(VNDCurrency.format(row.remaining))
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundStyle(
                    row.remaining >= 0 ? MonMonTheme.textPrimary : MonMonTheme.danger
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.remaining >= 0 ? "Left this month" : "Over budget")
                .accessibilityValue(VNDCurrency.format(row.remaining))
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
