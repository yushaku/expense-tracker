import SwiftData
import SwiftUI

struct IncomeAllocationTimelineView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @State private var selectedMonth: Date?
    @State private var preparation = IncomeAllocationTimeline.Preparation.empty
    @State private var didFailToBackfill = false

    private let asOf: Date

    private var unreadableAllocationMessage: LocalizedStringKey {
        "Some allocations are unreadable. Original records are unchanged."
    }

    init(asOf: Date = .now) {
        self.asOf = asOf
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        IncomeAllocationTimelineSummary(
                            totalAmount: preparation.totalAmount,
                            month: visibleMonth
                        )

                        if didFailToBackfill {
                            IncomeAllocationTimelineNotice(
                                text: "Couldn’t update older income allocations. Try again."
                            )
                        }

                        if preparation.invalidCount > 0 {
                            IncomeAllocationTimelineNotice(
                                text: unreadableAllocationMessage
                            )
                        }

                        if preparation.events.isEmpty {
                            ContentUnavailableView(
                                "No income recorded",
                                systemImage: "banknote",
                                description: Text(
                                    "Recorded income for this month will appear here."
                                )
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                        } else {
                            ForEach(preparation.events) { event in
                                IncomeAllocationEventCard(event: event)
                            }
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                monthRail
            }
            .navigationTitle("Income allocation")
            .accessibilityIdentifier("income-allocation-timeline")
            .task {
                backfillAndRefresh()
            }
            .onChange(of: visibleMonth) { _, _ in
                refresh()
            }
            .onChange(of: transactionRevision) { _, _ in
                refresh()
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private var visibleMonth: Date {
        selectedMonth ?? TransactionPeriod.startOfMonth(for: asOf)
    }

    private var monthRail: some View {
        let range = TransactionRange.month(containing: visibleMonth)
        let periods = PeriodRailPeriods(range: range, today: asOf)

        return PeriodRail(
            unit: periods.unit,
            periods: periods.periods,
            selection: periods.selection
        ) { period in
            selectedMonth = period
        }
        .background(MonMonTheme.canvas)
    }

    private var transactionRevision: [IncomeAllocationTimelineRevision] {
        transactions.map(IncomeAllocationTimelineRevision.init)
    }

    private func backfillAndRefresh() {
        do {
            _ = try IncomeAllocationLifecycle.backfillMissing(
                in: modelContext,
                capturedAt: asOf
            )
            didFailToBackfill = false
        } catch {
            didFailToBackfill = true
        }
        refresh()
    }

    private func refresh() {
        preparation = IncomeAllocationTimeline.prepare(
            transactions: transactions,
            monthContaining: visibleMonth
        )
    }
}

private struct IncomeAllocationTimelineRevision: Equatable {
    let id: UUID
    let kind: TransactionKind
    let amount: Decimal
    let occurredAt: Date
    let note: String
    let sourceRuleID: UUID?
    let sourceImportID: String?
    let snapshot: String?

    init(_ transaction: MoneyTransaction) {
        id = transaction.id
        kind = transaction.kind
        amount = transaction.amount
        occurredAt = transaction.occurredAt
        note = transaction.note
        sourceRuleID = transaction.sourceRuleID
        sourceImportID = transaction.sourceImportID
        snapshot = transaction.incomeAllocationSnapshot
    }
}

private struct IncomeAllocationTimelineSummary: View {
    let totalAmount: Decimal
    let month: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Income allocation history", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            Text(month, format: .dateTime.month(.wide).year())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.textSecondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Total received")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(VNDCurrency.format(totalAmount))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }

            Text(
                "Historical allocations stay frozen and may differ from your current Budget setup."
            )
            .font(.caption)
            .foregroundStyle(MonMonTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(MonMonTheme.hero, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(MonMonTheme.heroBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("income-allocation-summary")
    }
}

private struct IncomeAllocationTimelineNotice: View {
    let text: LocalizedStringKey

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(MonMonTheme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
    }
}

private struct IncomeAllocationEventCard: View {
    let event: IncomeAllocationTimeline.Event

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.occurredAt, format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)

                    Text(VNDCurrency.format(event.amount))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 8)

                IncomeAllocationSourceBadge(source: event.source)
            }

            if !event.note.isEmpty {
                Text(event.note)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            VStack(spacing: 12) {
                ForEach(event.snapshot.slices, id: \.jarID) { slice in
                    IncomeAllocationSliceRow(slice: slice)
                }

                if event.snapshot.unallocatedAmount > 0 {
                    IncomeAllocationUnallocatedRow(amount: event.snapshot.unallocatedAmount)
                }
            }

            if event.snapshot.isEstimated {
                Label("Estimated from current setup", systemImage: "clock.badge.questionmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MonMonTheme.textSecondary)
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
        .accessibilityIdentifier("income-allocation-event-\(event.id.uuidString)")
    }
}

private struct IncomeAllocationSourceBadge: View {
    let source: IncomeAllocationTimeline.Source

    var body: some View {
        Label(title, systemImage: symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MonMonTheme.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(MonMonTheme.accent.opacity(0.14), in: Capsule())
    }

    private var title: LocalizedStringKey {
        switch source {
        case .recurring:
            "Recurring"
        case .imported:
            "Imported"
        case .oneOff:
            "One-off"
        }
    }

    private var symbolName: String {
        switch source {
        case .recurring:
            "arrow.triangle.2.circlepath"
        case .imported:
            "tray.and.arrow.down.fill"
        case .oneOff:
            "pencil.line"
        }
    }
}

private struct IncomeAllocationSliceRow: View {
    let slice: IncomeAllocationSnapshot.Slice

    private var tint: Color {
        CategoryPalette.color(named: slice.colorName)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: CategoryPalette.symbolName(slice.symbolName))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(slice.name)
                    .font(.subheadline.weight(.semibold))

                Text("\(PercentInput.format(slice.percent))% allocation")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Text(VNDCurrency.format(slice.amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct IncomeAllocationUnallocatedRow: View {
    let amount: Decimal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(MonMonTheme.textMuted)
                .frame(width: 32, height: 32)
                .background(MonMonTheme.field, in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            Text("Unallocated")
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 8)

            Text(VNDCurrency.format(amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}
