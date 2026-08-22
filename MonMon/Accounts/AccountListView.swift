import SwiftData
import SwiftUI

struct AccountListView: View {
    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    var body: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty {
                    emptyState
                } else {
                    accountList
                }
            }
            .navigationTitle("Cash balances")
            .accessibilityIdentifier("account-list")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No cash accounts", systemImage: "wallet.bifold")
        } description: {
            Text("Your cash and bank accounts will appear here.")
        }
    }

    private var accountList: some View {
        List {
            Section {
                LabeledContent("Total cash") {
                    Text(VNDCurrency.format(CashBalanceSummary.total(of: accounts)))
                        .font(.headline)
                        .monospacedDigit()
                }
            }

            Section("Accounts") {
                ForEach(accounts) { account in
                    LabeledContent {
                        Text(VNDCurrency.format(account.openingBalance))
                            .monospacedDigit()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                                .font(.headline)
                            Text(account.kind.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private extension CashAccountKind {
    var displayName: String {
        switch self {
        case .cash:
            "Cash"
        case .bank:
            "Bank"
        }
    }
}
