import SwiftData
import SwiftUI

/// Identifies a debt by value rather than by model. The same narrowing the card
/// did is repeated on the far side, so the detail screen stays right when the
/// debt is edited or deleted from that very screen.
struct DebtRoute: Hashable {
    let debtID: UUID
}

struct DebtListView: View {
    @Environment(\.locale) private var locale

    @Query(sort: \Debt.createdAt, order: .forward)
    private var debts: [Debt]

    @Query(sort: \DebtPayment.occurredAt, order: .reverse)
    private var payments: [DebtPayment]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    private let asOf: Date

    @State private var direction: DebtDirection
    @State private var editorMode: DebtEditorMode?

    init(direction: DebtDirection = .borrowed, asOf: Date = .now) {
        _direction = State(initialValue: direction)
        self.asOf = asOf
    }

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    if accounts.isEmpty && debts.isEmpty {
                        noAccountsState
                    } else {
                        positionCard

                        directionTabs

                        selectedSection
                    }
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Debts")
        .accessibilityIdentifier("debt-list")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addDebtButton
            }
        }
        .appSheet(item: $editorMode) { mode in
            DebtEditorView(mode: mode)
        }
        .tint(MonMonTheme.accent)
    }

    private var addDebtButton: some View {
        Button("Add Debt", systemImage: "plus") {
            editorMode = .add
        }
        .accessibilityIdentifier("add-debt")
    }

    // MARK: - Position

    private var owed: Decimal {
        DebtSummary.totalOutstanding(of: debts, payments: payments, direction: .borrowed)
    }

    private var owedToMe: Decimal {
        DebtSummary.totalOutstanding(of: debts, payments: payments, direction: .lent)
    }

    private var positionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("OUTSTANDING DEBT", systemImage: "chart.pie.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            if doughnutItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("OUTSTANDING", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(MonMonTheme.textSecondary)

                    Text(VNDCurrency.format(Decimal.zero))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            } else {
                AllocationDoughnut(
                    context: AppText.string("Debts", in: locale).lowercased(),
                    items: doughnutItems,
                    totalLabel: AppText.string("OUTSTANDING", in: locale)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private var doughnutItems: [AllocationDoughnutItem] {
        [
            AllocationDoughnutItem(
                id: DebtDirection.borrowed.rawValue,
                name: DebtDirection.borrowed.displayName(in: locale),
                amount: owed,
                tint: MonMonTheme.credit,
                symbolName: DebtDirection.borrowed.symbolName
            ),
            AllocationDoughnutItem(
                id: DebtDirection.lent.rawValue,
                name: DebtDirection.lent.displayName(in: locale),
                amount: owedToMe,
                tint: MonMonTheme.lent,
                symbolName: DebtDirection.lent.symbolName
            ),
        ]
        .filter { $0.amount > 0 }
    }

    // MARK: - Sections

    private var directionTabs: some View {
        SegmentedTabs(
            label: "Debt direction",
            selection: $direction,
            options: DebtDirection.allCases,
            title: \.displayName
        )
        .accessibilityIdentifier("debt-direction")
    }

    @ViewBuilder
    private var selectedSection: some View {
        if selectedDebts.isEmpty {
            selectedEmptyState
        } else {
            section(direction.displayName, debts: selectedDebts, tint: selectedTint)
        }
    }

    private var selectedDebts: [Debt] {
        DebtSummary.sortedForDisplay(
            DebtSummary.matching(debts, direction: direction),
            payments: payments
        )
    }

    private var selectedTint: Color {
        direction == .borrowed ? MonMonTheme.credit : MonMonTheme.lent
    }

    @ViewBuilder
    private func section(
        _ title: LocalizedStringKey,
        debts group: [Debt],
        tint: Color
    ) -> some View {
        if !group.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text(title)
                        .font(.title3.weight(.semibold))

                    Text("\(group.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tint.opacity(0.16), in: Capsule())
                }

                ForEach(group) { debt in
                    NavigationLink {
                        DebtDetailView(
                            route: DebtRoute(debtID: debt.id),
                            asOf: asOf
                        )
                    } label: {
                        card(for: debt)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("debt-\(debt.id.uuidString)")
                    .accessibilityHint("Opens the debt and its payments.")
                }
            }
        }
    }

    private func card(for debt: Debt) -> some View {
        DebtCard(
            debt: debt,
            outstanding: DebtSummary.outstanding(for: debt, payments: payments),
            paid: DebtSummary.paid(for: debt, payments: payments),
            progress: DebtSummary.progress(for: debt, payments: payments),
            accountName: accountName(debt.accountID),
            isOverdue: DebtSummary.isOverdue(debt, payments: payments, asOf: asOf),
            projectedInterest: debt.projectedInterest(asOf: asOf)
        )
    }

    private func accountName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }?.name
    }

    // MARK: - Placeholders

    private var selectedEmptyState: some View {
        placeholder(
            title: direction == .borrowed ? "No borrowed debts" : "No lent debts",
            message: direction == .borrowed
                ? "Add money you owe to track repayments and the outstanding balance."
                : "Add money owed to you to track repayments and the outstanding balance."
        ) {
            addDebtButton
        }
    }

    private var noAccountsState: some View {
        placeholder(
            title: "Add an account first",
            message: "A debt needs somewhere for the money to land or leave from."
        ) {
            EmptyView()
        }
    }

    private func placeholder<Action: View>(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            action()
                .buttonStyle(.prominentAction)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }
}

#if DEBUG
    #Preview("Debts") {
        NavigationStack {
            DebtListView()
        }
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
        .modelContainer(PreviewData.populated)
    }
#endif
