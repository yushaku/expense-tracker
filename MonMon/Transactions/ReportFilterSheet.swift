import SwiftData
import SwiftUI

/// The parts of a report query that do not fit in a toolbar: which direction,
/// which categories, and which accounts the results are cut down to.
///
/// The period and the search words stay on the screen behind this, where they
/// are changed most often. What is picked here is what the owner sets once and
/// reads several answers through.
struct ReportFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var query: TransactionQuery

    let categories: [TransactionCategory]
    let accounts: [CashAccount]

    var body: some View {
        #if os(macOS)
            form
                .frame(minWidth: 460, minHeight: 520)
        #else
            form
        #endif
    }

    private var form: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        directionCard
                        categoriesCard
                        accountsCard
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Filters")
            .accessibilityIdentifier("report-filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        clear()
                    }
                    .disabled(!query.isNarrowed)
                    .accessibilityIdentifier("clear-report-filters")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    /// Clearing leaves the period alone: it is the one filter the screen is
    /// never without, and it is changed from the toolbar rather than here.
    private func clear() {
        query.text = ""
        query.filter = .all
        query.categoryIDs = []
        query.accountIDs = []
    }

    private var directionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Direction", systemImage: "arrow.left.arrow.right")

                SegmentedTabs(
                    label: "Direction",
                    selection: $query.filter,
                    options: TransactionListFilter.allCases,
                    title: \.displayName
                )
                .accessibilityIdentifier("report-direction")
            }
        }
    }

    private var categoriesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Categories", systemImage: "tag.fill")

                if categories.isEmpty {
                    emptyNotice("No categories yet.")
                } else {
                    ForEach(categories) { category in
                        toggleRow(
                            name: category.name,
                            symbolName: CategoryPalette.symbolName(category.symbolName),
                            tint: CategoryPalette.color(named: category.colorName),
                            isOn: query.categoryIDs.contains(category.id),
                            identifier: "report-category-\(category.id.uuidString)"
                        ) {
                            toggle(category.id, in: &query.categoryIDs)
                        }
                    }
                }
            }
        }
    }

    private var accountsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Accounts", systemImage: "wallet.bifold.fill")

                if accounts.isEmpty {
                    emptyNotice("No accounts yet.")
                } else {
                    ForEach(accounts) { account in
                        toggleRow(
                            name: account.name,
                            symbolName: account.kind.iconName,
                            tint: account.kind.tint,
                            isOn: query.accountIDs.contains(account.id),
                            identifier: "report-account-\(account.id.uuidString)"
                        ) {
                            toggle(account.id, in: &query.accountIDs)
                        }
                    }
                }
            }
        }
    }

    /// Picking nothing means every one of them, so unticking the last one leaves
    /// the filter off rather than leaving the results empty.
    private func toggle(_ id: UUID, in ids: inout Set<UUID>) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
    }

    private func toggleRow(
        name: String,
        symbolName: String,
        tint: Color,
        isOn: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)

                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MonMonTheme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isOn ? MonMonTheme.accent : MonMonTheme.textMuted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func emptyNotice(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.textSecondary)
    }

    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(MonMonTheme.textPrimary)
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
