import SwiftData
import SwiftUI

struct SavingsListView: View {
    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @State private var editorMode: SavingsEditorMode?

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        summaryCard

                        if deposits.isEmpty {
                            emptyState
                        } else {
                            depositsSection
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, FloatingAddButton.contentInset)
                    .frame(maxWidth: .infinity)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !deposits.isEmpty {
                    FloatingAddButton(
                        title: "Add Savings Book",
                        accessibilityIdentifier: "add-savings"
                    ) {
                        editorMode = .add
                    }
                }
            }
            .navigationTitle("Savings")
            .accessibilityIdentifier("savings-list")
            .sheet(item: $editorMode) { mode in
                SavingsEditorView(mode: mode)
            }
            .tint(MonMonTheme.accent)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("TOTAL SAVINGS", systemImage: "building.columns.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(VNDCurrency.format(AssetSummary.totalPrincipal(of: deposits)))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(MonMonTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Label(
                    "Projected interest \(VNDCurrency.format(projectedInterest))",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .font(.subheadline.weight(.medium))

                Label(depositCountLabel, systemImage: "rectangle.stack.fill")
                    .font(.subheadline.weight(.medium))
            }
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
        .accessibilityElement(children: .combine)
    }

    private var projectedInterest: Decimal {
        AssetSummary.totalProjectedInterest(of: deposits)
    }

    private var depositCountLabel: String {
        switch deposits.count {
        case 0:
            "Ready for your first savings book"
        case 1:
            "Across 1 savings book"
        default:
            "Across \(deposits.count) savings books"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.savings)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.savings.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Track your savings books")
                    .font(.title3.weight(.semibold))

                Text(
                    "Add a term deposit to see its maturity date and the interest it will pay."
                )
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            }

            addDepositButton
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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

    private func accountName(for deposit: SavingsDeposit) -> String? {
        guard let sourceAccountID = deposit.sourceAccountID else {
            return nil
        }

        return accounts.first { $0.id == sourceAccountID }?.name
    }

    private var addDepositButton: some View {
        Button("Add Savings Book", systemImage: "plus") {
            editorMode = .add
        }
        .accessibilityIdentifier("add-savings")
    }

    private var depositsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Savings books")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(deposits.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.savings)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.savings.opacity(0.16), in: Capsule())
            }

            ForEach(deposits) { deposit in
                Button {
                    editorMode = .edit(deposit)
                } label: {
                    SavingsDepositCard(
                        deposit: deposit,
                        sourceAccountName: accountName(for: deposit)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("savings-\(deposit.id.uuidString)")
                .accessibilityHint("Opens this savings book for editing")
            }
        }
    }
}

#if DEBUG
    #Preview("Savings · deposits") {
        SavingsListView()
            .modelContainer(PreviewData.populated)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }

    #Preview("Savings · empty state") {
        SavingsListView()
            .modelContainer(PreviewData.empty)
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
