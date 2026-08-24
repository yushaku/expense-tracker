import SwiftData
import SwiftUI

/// The rules the owner has set up, opened as a sheet from the Spending screen —
/// where `CategoryListView` already opens from.
struct RecurringListView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \RecurringRule.createdAt, order: .forward)
    private var rules: [RecurringRule]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    private let asOf: Date

    @State private var editorMode: RecurringEditorMode?

    init(asOf: Date = .now) {
        self.asOf = asOf
    }

    var body: some View {
        #if os(macOS)
            list
                .frame(minWidth: 460, minHeight: 600)
        #else
            list
        #endif
    }

    private var list: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        if accounts.isEmpty {
                            noAccountState
                        } else if rules.isEmpty {
                            emptyState
                        } else {
                            monthCard

                            section("Active", rules: activeRules)
                            section("Paused", rules: pausedRules)
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Recurring")
            .accessibilityIdentifier("recurring-list")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !accounts.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add Rule", systemImage: "plus") {
                            editorMode = .add
                        }
                        .accessibilityIdentifier("add-recurring")
                    }
                }
            }
            .sheet(item: $editorMode) { mode in
                RecurringEditorView(mode: mode, defaultDate: asOf, asOf: asOf)
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private var activeRules: [RecurringRule] {
        RecurringSummary.sortedForDisplay(RecurringSummary.active(rules), asOf: asOf)
    }

    private var pausedRules: [RecurringRule] {
        RecurringSummary.sortedForDisplay(RecurringSummary.paused(rules), asOf: asOf)
    }

    /// What the rules add up to over the month being lived through, so a weekly
    /// and a monthly rule can be read as one figure.
    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("This month".uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(signedNet)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(MonMonTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Label(
                    "Coming in \(VNDCurrency.format(monthlyIncome))",
                    systemImage: TransactionKind.income.symbolName
                )
                .font(.subheadline.weight(.medium))

                Label(
                    "Going out \(VNDCurrency.format(monthlyExpense))",
                    systemImage: TransactionKind.expense.symbolName
                )
                .font(.subheadline.weight(.medium))

                Label(countLabel, systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(MonMonTheme.textSecondary)
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

    private var monthlyIncome: Decimal {
        amount(of: .income)
    }

    private var monthlyExpense: Decimal {
        amount(of: .expense)
    }

    private func amount(of kind: TransactionKind) -> Decimal {
        rules.reduce(Decimal.zero) { total, rule in
            rule.kind == kind
                ? total + RecurringSummary.monthlyAmount(of: rule, asOf: asOf) : total
        }
    }

    /// The sign is written out rather than left to the minus the formatter would
    /// place, so a surplus reads as clearly as a shortfall.
    private var signedNet: String {
        let net = RecurringSummary.monthlyNet(of: rules, asOf: asOf)
        let magnitude = net < 0 ? -net : net
        let sign = net < 0 ? "−" : "+"

        return "\(sign)\(VNDCurrency.format(magnitude))"
    }

    private var countLabel: LocalizedStringKey {
        let active = activeRules.count
        let noun = active == 1 ? "active rule" : "active rules"
        guard !pausedRules.isEmpty else {
            return "\(active) \(noun)"
        }

        return "\(active) \(noun) · \(pausedRules.count) paused"
    }

    @ViewBuilder
    private func section(_ title: String, rules: [RecurringRule]) -> some View {
        if !rules.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))

                ForEach(rules) { rule in
                    Button {
                        editorMode = .edit(rule)
                    } label: {
                        RecurringCard(
                            rule: rule,
                            category: category(for: rule),
                            account: account(for: rule),
                            asOf: asOf
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recurring-\(rule.id.uuidString)")
                    .accessibilityHint("Opens the rule editor.")
                }
            }
        }
    }

    private func category(for rule: RecurringRule) -> TransactionCategory? {
        guard let categoryID = rule.categoryID else {
            return nil
        }

        return categories.first { $0.id == categoryID }
    }

    private func account(for rule: RecurringRule) -> CashAccount? {
        accounts.first { $0.id == rule.accountID }
    }

    private var emptyState: some View {
        placeholder(
            symbolName: "arrow.triangle.2.circlepath",
            title: "Nothing repeats yet",
            message: "Rent, salary, a subscription — record it once and it keeps itself."
        ) {
            Button("Add Rule") {
                editorMode = .add
            }
            .accessibilityIdentifier("add-recurring")
        }
    }

    private var noAccountState: some View {
        placeholder(
            symbolName: "wallet.bifold.fill",
            title: "Add an account first",
            message: "Every entry a rule records moves one account, so there has to be one."
        ) {
            EmptyView()
        }
    }

    private func placeholder<Action: View>(
        symbolName: String,
        title: String,
        message: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: symbolName)
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
