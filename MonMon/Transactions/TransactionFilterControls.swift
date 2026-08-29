import SwiftUI

struct TransactionSearchButton: View {
    let isActive: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "magnifyingglass")
                    .font(.footnote.weight(.bold))
                    .frame(width: 30, height: 30)

                if isActive {
                    Circle()
                        .fill(MonMonTheme.accent)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .headerIconStyle()
        .accessibilityLabel("Search transactions")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

/// The search and structured filters currently narrowing a transaction query,
/// each removable without reopening the filter sheet.
struct TransactionFilterChips: View {
    @Environment(\.locale) private var locale

    @Binding var query: TransactionQuery

    let categories: [TransactionCategory]
    let accounts: [CashAccount]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                chips
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chips
                }
            }
        }
    }

    @ViewBuilder
    private var chips: some View {
        if !query.trimmedText.isEmpty {
            chip(query.trimmedText, systemImage: "magnifyingglass") {
                query.text = ""
            }
        }

        if query.filter != .all {
            chip(
                AppText.string(key: filterName, in: locale),
                systemImage: "arrow.left.arrow.right"
            ) {
                query.filter = .all
            }
        }

        ForEach(selectedCategories) { category in
            chip(category.name, systemImage: CategoryPalette.symbolName(category.symbolName)) {
                query.categoryIDs.remove(category.id)
            }
        }

        ForEach(selectedAccounts) { account in
            chip(account.name, systemImage: account.kind.iconName) {
                query.accountIDs.remove(account.id)
            }
        }

        Spacer(minLength: 0)
    }

    private var filterName: String {
        query.filter.kind?.nameKey ?? "All"
    }

    private var selectedCategories: [TransactionCategory] {
        categories.filter { query.categoryIDs.contains($0.id) }
    }

    private var selectedAccounts: [CashAccount] {
        accounts.filter { query.accountIDs.contains($0.id) }
    }

    private func chip(
        _ title: String,
        systemImage: String,
        onRemove: @escaping () -> Void
    ) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(MonMonTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(MonMonTheme.accent.opacity(0.14), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove filter \(title)")
    }
}
