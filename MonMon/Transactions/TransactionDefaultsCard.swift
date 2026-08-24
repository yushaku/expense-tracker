import SwiftData
import SwiftUI

/// The account and the two categories a new entry starts on.
///
/// It owns the preferences rather than taking them as bindings, so the screen
/// presenting it never holds a copy that could drift from what the editors
/// actually read. It carries no heading of its own: it is shown inside
/// `TransactionDefaultsView`, whose navigation title already names it.
struct TransactionDefaultsCard: View {
    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @AppStorage(TransactionDefaults.accountStorageKey)
    private var defaultAccountValue = ""
    @AppStorage(TransactionDefaults.categoryStorageKey)
    private var defaultExpenseCategoryValue = ""
    @AppStorage(TransactionDefaults.incomeCategoryStorageKey)
    private var defaultIncomeCategoryValue = ""

    var body: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                picker(
                    title: "Account",
                    selection: $defaultAccountValue,
                    isEmpty: accounts.isEmpty,
                    isSelectionValid: accounts.contains {
                        $0.id.uuidString == defaultAccountValue
                    },
                    emptyMessage: "Add an account to choose a default.",
                    accessibilityIdentifier: "default-transaction-account"
                ) {
                    ForEach(accounts) { account in
                        Text(account.name)
                            .tag(account.id.uuidString)
                    }
                }

                divider

                picker(
                    title: "Expense category",
                    selection: $defaultExpenseCategoryValue,
                    isEmpty: expenseCategories.isEmpty,
                    isSelectionValid: expenseCategories.contains {
                        $0.id.uuidString == defaultExpenseCategoryValue
                    },
                    emptyMessage: "Add an expense category to choose a default.",
                    accessibilityIdentifier: "default-transaction-category"
                ) {
                    ForEach(expenseCategories) { category in
                        Text(category.name)
                            .tag(category.id.uuidString)
                    }
                }

                divider

                picker(
                    title: "Income category",
                    selection: $defaultIncomeCategoryValue,
                    isEmpty: incomeCategories.isEmpty,
                    isSelectionValid: incomeCategories.contains {
                        $0.id.uuidString == defaultIncomeCategoryValue
                    },
                    emptyMessage: "Add an income category to choose a default.",
                    accessibilityIdentifier: "default-transaction-income-category"
                ) {
                    ForEach(incomeCategories) { category in
                        Text(category.name)
                            .tag(category.id.uuidString)
                    }
                }

                Text(
                    """
                    New entries start as expenses on these values, and switching to income \
                    picks up the income one.
                    """
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .onAppear {
            persistInitialDefaults()
        }
    }

    private var divider: some View {
        Divider()
            .overlay(MonMonTheme.border)
    }

    private var expenseCategories: [TransactionCategory] {
        categories.filter { $0.kind == .expense }
    }

    private var incomeCategories: [TransactionCategory] {
        categories.filter { $0.kind == .income }
    }

    /// Writes what the app would have fallen back on anyway, so the picker shows
    /// the value a new entry actually starts on rather than an empty row.
    private func persistInitialDefaults() {
        if defaultAccountValue.isEmpty,
            let accountID = TransactionDefaults.resolveAccountID("", accounts: accounts)
        {
            defaultAccountValue = accountID.uuidString
        }

        if defaultExpenseCategoryValue.isEmpty,
            let categoryID = TransactionDefaults.resolveCategoryID(
                "",
                categories: categories,
                kind: .expense
            )
        {
            defaultExpenseCategoryValue = categoryID.uuidString
        }

        if defaultIncomeCategoryValue.isEmpty,
            let categoryID = TransactionDefaults.resolveCategoryID(
                "",
                categories: categories,
                kind: .income
            )
        {
            defaultIncomeCategoryValue = categoryID.uuidString
        }
    }

    @ViewBuilder
    private func picker<Options: View>(
        title: String,
        selection: Binding<String>,
        isEmpty: Bool,
        isSelectionValid: Bool,
        emptyMessage: String,
        accessibilityIdentifier: String,
        @ViewBuilder options: () -> Options
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))

            if isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            } else {
                Picker(title, selection: selection) {
                    if !isSelectionValid {
                        Text("Choose")
                            .tag(selection.wrappedValue)
                    }

                    options()
                }
                .labelsHidden()
                .accessibilityIdentifier(accessibilityIdentifier)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
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
}
