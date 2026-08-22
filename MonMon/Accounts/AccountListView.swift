import SwiftData
import SwiftUI

struct AccountListView: View {
    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @State private var isAddingAccount = false

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        totalCard

                        if accounts.isEmpty {
                            emptyState
                        } else {
                            accountsSection
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Cash balances")
            .accessibilityIdentifier("account-list")
            .toolbar {
                if !accounts.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        addAccountButton
                    }
                }
            }
            .sheet(isPresented: $isAddingAccount) {
                AddAccountView()
            }
            .tint(MonMonTheme.accent)
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("TOTAL CASH", systemImage: "banknote.fill")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.72))

            Text(VNDCurrency.format(CashBalanceSummary.total(of: accounts)))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(.white)
                .accessibilityLabel("Total cash")

            Label(accountCountLabel, systemImage: "rectangle.stack.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.hero)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var accountCountLabel: String {
        switch accounts.count {
        case 0:
            "Ready for your first account"
        case 1:
            "Across 1 account"
        default:
            "Across \(accounts.count) accounts"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "wallet.bifold.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.accent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Build your cash picture")
                    .font(.title3.weight(.semibold))

                Text("Add cash and bank accounts to see everything in one calm overview.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            addAccountButton
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

    private var addAccountButton: some View {
        Button("Add Account", systemImage: "plus") {
            isAddingAccount = true
        }
        .accessibilityIdentifier("add-account")
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accounts")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(accounts.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.accent.opacity(0.12), in: Capsule())
            }

            ForEach(accounts) { account in
                CashAccountCard(account: account)
            }
        }
    }
}
