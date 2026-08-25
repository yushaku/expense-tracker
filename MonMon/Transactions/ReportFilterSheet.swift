import SwiftData
import SwiftUI

/// The report query behind one compact toolbar: search words, direction,
/// categories, and accounts. Search lives here rather than occupying the
/// report header; opening from its toolbar icon puts the keyboard straight in
/// the field, while opening from the filter icon leaves the whole sheet ready.
struct ReportFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    @Binding var query: TransactionQuery

    let categories: [TransactionCategory]
    let accounts: [CashAccount]
    let focusesSearchOnAppear: Bool

    private let selectionColumns = [GridItem(.adaptive(minimum: 140), spacing: 10)]

    init(
        query: Binding<TransactionQuery>,
        categories: [TransactionCategory],
        accounts: [CashAccount],
        focusesSearchOnAppear: Bool = false
    ) {
        _query = query
        self.categories = categories
        self.accounts = accounts
        self.focusesSearchOnAppear = focusesSearchOnAppear
    }

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
                        searchCard
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
            .navigationTitle("Search & Filters")
            .accessibilityIdentifier("report-filters")
            .task {
                guard focusesSearchOnAppear else {
                    return
                }

                await Task.yield()
                isSearchFocused = true
            }
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

    /// Clearing leaves the period alone: it is the one filter the report is
    /// never without, and the calendar changes it outside this sheet.
    private func clear() {
        query.text = ""
        query.filter = .all
        query.categoryIDs = []
        query.accountIDs = []
    }

    private var searchCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Search", systemImage: "magnifyingglass")

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MonMonTheme.textMuted)
                        .accessibilityHidden(true)

                    TextField("Notes, categories, amounts", text: $query.text)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            dismiss()
                        }
                        .accessibilityIdentifier("report-search-field")

                    if query.hasSearchText {
                        Button {
                            query.text = ""
                            isSearchFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(MonMonTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                .background(MonMonTheme.field, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MonMonTheme.border, lineWidth: 1)
                }
            }
        }
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
                    LazyVGrid(columns: selectionColumns, alignment: .leading, spacing: 10) {
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
    }

    private var accountsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Accounts", systemImage: "wallet.bifold.fill")

                if accounts.isEmpty {
                    emptyNotice("No accounts yet.")
                } else {
                    LazyVGrid(columns: selectionColumns, alignment: .leading, spacing: 10) {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .background(
                isOn ? MonMonTheme.accent.opacity(0.14) : MonMonTheme.field,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOn ? MonMonTheme.accent : MonMonTheme.border, lineWidth: 1)
            }
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
