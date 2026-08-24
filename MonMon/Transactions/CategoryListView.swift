import SwiftData
import SwiftUI

struct CategoryListView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @Query(sort: \MoneyTransaction.occurredAt, order: .reverse)
    private var transactions: [MoneyTransaction]

    @State private var editorMode: CategoryEditorMode?

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
                        if categories.isEmpty {
                            emptyState
                        } else {
                            section(for: .expense)
                            section(for: .income)
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Categories")
            .accessibilityIdentifier("category-list")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Add Category", systemImage: "plus") {
                        editorMode = .add
                    }
                    .accessibilityIdentifier("add-category")
                }
            }
            .sheet(item: $editorMode) { mode in
                CategoryEditorView(mode: mode)
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    @ViewBuilder
    private func section(for kind: TransactionKind) -> some View {
        let matching = categories.filter { $0.kind == kind }

        if !matching.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(kind.displayName, systemImage: kind.symbolName)
                        .font(.title3.weight(.semibold))

                    Spacer()

                    Text(matching.count.formatted())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MonMonTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(MonMonTheme.accent.opacity(0.16), in: Capsule())
                }

                ForEach(matching) { category in
                    Button {
                        editorMode = .edit(category)
                    } label: {
                        row(for: category)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("category-\(category.id.uuidString)")
                    .accessibilityHint("Opens the category editor.")
                }
            }
        }
    }

    private func row(for category: TransactionCategory) -> some View {
        HStack(spacing: 14) {
            Image(systemName: CategoryPalette.symbolName(category.symbolName))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CategoryPalette.color(named: category.colorName))
                .frame(width: 44, height: 44)
                .background(
                    CategoryPalette.color(named: category.colorName).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(usageLabel(for: category))
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MonMonTheme.textMuted)
                .accessibilityHidden(true)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func usageLabel(for category: TransactionCategory) -> String {
        let count = TransactionSummary.count(for: category, transactions: transactions)

        switch count {
        case 0:
            return "Not used yet"
        case 1:
            return "1 transaction"
        default:
            return "\(count) transactions"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "tag.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("No categories yet")
                    .font(.title3.weight(.semibold))

                Text("Add one so your transactions can be grouped.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button("Add Category", systemImage: "plus") {
                editorMode = .add
            }
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
