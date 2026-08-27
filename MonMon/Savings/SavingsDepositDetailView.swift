import SwiftData
import SwiftUI

struct SavingsDepositRoute: Hashable {
    let depositID: UUID
}

private enum SavingsDepositDetailEditor: Identifiable {
    case deposit(SavingsEditorMode)
    case withdrawal(SavingsWithdrawalEditorMode)

    var id: String {
        switch self {
        case .deposit(let mode):
            "deposit-\(mode.id)"
        case .withdrawal(let mode):
            "withdrawal-\(mode.id)"
        }
    }
}

struct SavingsDepositDetailView: View {
    @Environment(\.locale) private var locale

    let route: SavingsDepositRoute

    @Query(sort: \SavingsDeposit.createdAt, order: .forward)
    private var deposits: [SavingsDeposit]

    @Query(sort: \SavingsWithdrawal.withdrawnAt, order: .reverse)
    private var withdrawals: [SavingsWithdrawal]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @State private var editor: SavingsDepositDetailEditor?

    var asOf: Date = .now

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    if let deposit {
                        overview(for: deposit)
                        terms(for: deposit)
                        history(for: deposit)
                    } else {
                        ContentUnavailableView(
                            "Savings book unavailable",
                            systemImage: "building.columns",
                            description: Text("This savings book may have been deleted.")
                        )
                    }
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(deposit?.name ?? "Savings book")
        .accessibilityIdentifier("savings-detail-\(route.depositID.uuidString)")
        .toolbar {
            if let deposit, deposit.remainingPrincipal(withdrawals: withdrawals) > 0 {
                ToolbarItem(placement: .primaryAction) {
                    Button(withdrawActionTitle(for: deposit), systemImage: "arrow.down.to.line") {
                        editor = .withdrawal(.add(deposit))
                    }
                    .accessibilityIdentifier("savings-withdraw")
                }
            }
        }
        .appSheet(item: $editor) { editor in
            switch editor {
            case .deposit(let mode):
                SavingsEditorView(mode: mode)
            case .withdrawal(let mode):
                SavingsWithdrawalEditorView(mode: mode)
            }
        }
        .tint(MonMonTheme.accent)
    }

    private var deposit: SavingsDeposit? {
        deposits.first { $0.id == route.depositID }
    }

    private func overview(for deposit: SavingsDeposit) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MonMonTheme.onAccent)
                    .frame(width: 48, height: 48)
                    .background(MonMonTheme.savings, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(statusTitle(for: deposit))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusColor(for: deposit))

                    Text(VNDCurrency.format(deposit.remainingPrincipal(withdrawals: withdrawals)))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    Text("Remaining principal")
                        .font(.subheadline)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                Spacer(minLength: 8)

                Button("Edit", systemImage: "pencil") {
                    editor = .deposit(.edit(deposit))
                }
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("edit-savings")
            }

            HStack(spacing: 12) {
                metric(
                    title: "PROJECTED INTEREST",
                    value: VNDCurrency.format(deposit.projectedInterest(withdrawals: withdrawals))
                )
                metric(
                    title: "REALIZED INTEREST",
                    value: VNDCurrency.format(
                        SavingsWithdrawalSummary.realizedInterest(
                            for: deposit,
                            withdrawals: withdrawals
                        )
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private func terms(for deposit: SavingsDeposit) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Deposit terms", systemImage: "doc.text.fill")
                .font(.headline)

            detail("Original principal", VNDCurrency.format(deposit.principal))
            detail("Annual rate", PercentInput.formatWithSymbol(deposit.annualInterestRate))
            detail("Term", AppText.string("\(deposit.termMonths) months", in: locale))
            detail("Opened on", TransactionPeriod.day(deposit.openedAt, in: locale))
            detail("Maturity date", TransactionPeriod.day(deposit.maturityDate, in: locale))

            if let accountName = accountName(forID: deposit.sourceAccountID) {
                detail("Funded from", accountName)
            }

            if !depositWithdrawals.isEmpty {
                Label(
                    "Financial terms are locked because this book has withdrawal history.",
                    systemImage: "lock.fill"
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private func history(for deposit: SavingsDeposit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Withdrawal history")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(depositWithdrawals.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.savings)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.savings.opacity(0.16), in: Capsule())
            }

            if depositWithdrawals.isEmpty {
                Text("No money has been withdrawn from this book yet.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        MonMonTheme.surface,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            } else {
                ForEach(depositWithdrawals) { withdrawal in
                    Button {
                        editor = .withdrawal(.edit(withdrawal))
                    } label: {
                        SavingsWithdrawalCard(
                            withdrawal: withdrawal,
                            destinationAccountName: accountName(
                                forID: withdrawal.destinationAccountID
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("savings-withdrawal-\(withdrawal.id.uuidString)")
                    .accessibilityHint("Opens this withdrawal for editing")
                }
            }
        }
    }

    private var depositWithdrawals: [SavingsWithdrawal] {
        guard let deposit else { return [] }
        return SavingsWithdrawalSummary.withdrawals(for: deposit, withdrawals: withdrawals)
    }

    private func metric(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MonMonTheme.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detail(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }

    private func statusTitle(for deposit: SavingsDeposit) -> LocalizedStringKey {
        switch deposit.status(withdrawals: withdrawals, asOf: asOf) {
        case .active:
            "ACTIVE"
        case .matured:
            "MATURED — READY TO SETTLE"
        case .settled:
            "SETTLED"
        }
    }

    private func statusColor(for deposit: SavingsDeposit) -> Color {
        switch deposit.status(withdrawals: withdrawals, asOf: asOf) {
        case .active:
            MonMonTheme.savings
        case .matured:
            MonMonTheme.accent
        case .settled:
            MonMonTheme.textSecondary
        }
    }

    private func withdrawActionTitle(for deposit: SavingsDeposit) -> LocalizedStringKey {
        deposit.status(withdrawals: withdrawals, asOf: asOf) == .matured
            ? "Settle" : "Withdraw"
    }

    private func accountName(forID id: UUID?) -> String? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }?.name
    }
}
