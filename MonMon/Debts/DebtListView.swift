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

    @State private var editorMode: DebtEditorMode?

    init(asOf: Date = .now) {
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
                    } else if debts.isEmpty {
                        emptyState
                    } else {
                        positionCard

                        section(
                            "Money I owe",
                            debts: DebtSummary.sortedForDisplay(borrowed, payments: payments),
                            tint: MonMonTheme.credit
                        )

                        section(
                            "Money owed to me",
                            debts: DebtSummary.sortedForDisplay(lent, payments: payments),
                            tint: MonMonTheme.lent
                        )
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
        .sheet(item: $editorMode) { mode in
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

    private var borrowed: [Debt] { debts.filter { $0.direction == .borrowed } }
    private var lent: [Debt] { debts.filter { $0.direction == .lent } }

    private var owed: Decimal {
        DebtSummary.totalOutstanding(of: debts, payments: payments, direction: .borrowed)
    }

    private var owedToMe: Decimal {
        DebtSummary.totalOutstanding(of: debts, payments: payments, direction: .lent)
    }

    private var netPosition: Decimal { owedToMe - owed }

    /// Net position answers which side is larger; the doughnut underneath says
    /// how the two outstanding balances make up the whole debt picture.
    private var positionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("NET POSITION", systemImage: "scalemass.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(netPositionText)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(netPositionTint)

            Divider()
                .overlay(MonMonTheme.heroBorder)

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

            Divider()
                .overlay(MonMonTheme.heroBorder)

            Label(countLabel, systemImage: "rectangle.stack.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.hero)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.heroBorder, lineWidth: 1)
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

    private var netPositionText: String {
        netPosition < 0
            ? "−\(VNDCurrency.format(-netPosition))" : VNDCurrency.format(netPosition)
    }

    private var netPositionTint: Color {
        if netPosition < 0 {
            MonMonTheme.credit
        } else if netPosition > 0 {
            MonMonTheme.lent
        } else {
            MonMonTheme.textPrimary
        }
    }

    private var countLabel: LocalizedStringKey {
        "\(debts.count) debts"
    }

    // MARK: - Sections

    @ViewBuilder
    private func section(_ title: String, debts group: [Debt], tint: Color) -> some View {
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

    private var emptyState: some View {
        placeholder(
            title: "Nothing borrowed or lent",
            message: """
                Record money you owe and money owed to you. Your total assets stay the same either\
                 way.
                """
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
        title: String,
        message: String,
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
