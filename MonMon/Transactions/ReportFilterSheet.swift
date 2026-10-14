import SwiftData
import SwiftUI

/// A transaction query behind one compact toolbar: search words, direction,
/// categories, and accounts. Search lives here rather than occupying the
/// screen header; opening from its toolbar icon puts the keyboard straight in
/// the field, while opening from the filter icon leaves the whole sheet ready.
struct ReportFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var query: TransactionQuery

    let categories: [TransactionCategory]
    let accounts: [CashAccount]
    let focusesSearchOnAppear: Bool
    let identifierPrefix: String

    init(
        query: Binding<TransactionQuery>,
        categories: [TransactionCategory],
        accounts: [CashAccount],
        focusesSearchOnAppear: Bool = false,
        identifierPrefix: String = "report-"
    ) {
        _query = query
        self.categories = categories
        self.accounts = accounts
        self.focusesSearchOnAppear = focusesSearchOnAppear
        self.identifierPrefix = identifierPrefix
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
                        TransactionFilterFields(
                            query: $query, categories: categories, accounts: accounts,
                            identifierPrefix: identifierPrefix,
                            focusesSearchOnAppear: focusesSearchOnAppear,
                            onSubmit: { dismiss() }
                        )
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Search & Filters")
            .accessibilityIdentifier("\(identifierPrefix)filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        clear()
                    }
                    .disabled(!query.isNarrowed)
                    .accessibilityIdentifier("clear-\(identifierPrefix)filters")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .tint(MonMonTheme.textSecondary)
                }
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    /// Clearing leaves the period alone: it is the one filter the screen is
    /// never without, and the date controls change it outside this sheet.
    private func clear() {
        query.text = ""
        query.filter = .all
        query.categoryIDs = []
        query.accountIDs = []
    }

}

/// Shared controls; Transactions adds its period here while Report keeps its own date controls.
private struct TransactionFilterFields: View {
    @Environment(\.locale) private var locale
    @Environment(\.appDateFormat) private var dateFormat
    @FocusState private var isSearchFocused: Bool
    @Binding var query: TransactionQuery
    let categories: [TransactionCategory]
    let accounts: [CashAccount]
    let identifierPrefix: String
    var focusesSearchOnAppear = false
    var includesPeriod = false
    let onSubmit: () -> Void

    private let selectionColumns = [GridItem(.adaptive(minimum: 140), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
            searchCard
            if includesPeriod { periodCard }
            if !includesPeriod { directionCard }
            if includesPeriod {
                DisclosureGroup {
                    categoriesCard
                } label: {
                    selectionLabel("Categories", symbol: "tag.fill", count: query.categoryIDs.count)
                }
                .appCard()
                DisclosureGroup {
                    accountsCard
                } label: {
                    selectionLabel(
                        "Accounts", symbol: "wallet.bifold.fill", count: query.accountIDs.count)
                }
                .appCard()
            } else {
                categoriesCard
                accountsCard
            }
        }
        .task {
            guard focusesSearchOnAppear else { return }
            await Task.yield()
            isSearchFocused = true
        }
    }

    private func selectionLabel(_ title: LocalizedStringKey, symbol: String, count: Int)
        -> some View
    {
        HStack {
            sectionHeader(title, systemImage: symbol)
            Spacer(minLength: 8)
            if count == 0 {
                Text("All").foregroundStyle(MonMonTheme.textSecondary)
            } else {
                Text("\(count) selected").foregroundStyle(MonMonTheme.accent)
            }
        }
        .font(.subheadline)
        .frame(minHeight: 44)
    }

    private var periodCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink {
                VStack(alignment: .leading, spacing: 0) {
                    DateRangeFilter(range: $query.range, identifierPrefix: "spending")
                    Spacer(minLength: 0)
                }
                .padding(20)
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(MonMonTheme.canvas)
                .navigationTitle("Period")
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("Period", systemImage: "calendar")
                        Text(query.range.title(in: locale, dateFormat: dateFormat))
                            .font(.subheadline)
                            .foregroundStyle(MonMonTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("spending-filter-period")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                periodShortcut("Today", range: .day(containing: .now))
                periodShortcut("This week", range: .week(containing: .now))
                periodShortcut("This month", range: .month(containing: .now))
                periodShortcut("This year", range: .year(containing: .now))
            }
        }
        .appCard()
    }

    private func periodShortcut(_ title: LocalizedStringKey, range: TransactionRange) -> some View {
        Button {
            query.range = range
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    query.range == range ? MonMonTheme.accent.opacity(0.14) : MonMonTheme.field,
                    in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .foregroundStyle(query.range == range ? MonMonTheme.accent : MonMonTheme.textPrimary)
        .accessibilityAddTraits(query.range == range ? [.isSelected] : [])
    }

    private var searchCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                if !includesPeriod {
                    sectionHeader("Search", systemImage: "magnifyingglass")
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MonMonTheme.textMuted)
                        .accessibilityHidden(true)

                    TextField("Notes, categories, amounts", text: $query.text)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            onSubmit()
                        }
                        .accessibilityIdentifier("\(identifierPrefix)search-field")

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
                .accessibilityIdentifier("\(identifierPrefix)direction")
            }
        }
    }

    private var categoriesCard: some View {
        selectionCard {
            VStack(alignment: .leading, spacing: 14) {
                if !includesPeriod { sectionHeader("Categories", systemImage: "tag.fill") }

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
                                identifier: "\(identifierPrefix)category-\(category.id.uuidString)"
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
        selectionCard {
            VStack(alignment: .leading, spacing: 14) {
                if !includesPeriod { sectionHeader("Accounts", systemImage: "wallet.bifold.fill") }

                if accounts.isEmpty {
                    emptyNotice("No accounts yet.")
                } else {
                    LazyVGrid(columns: selectionColumns, alignment: .leading, spacing: 10) {
                        ForEach(accounts) { account in
                            toggleRow(
                                name: account.name,
                                symbolName: account.kind.iconName,
                                tint: account.tint,
                                isOn: query.accountIDs.contains(account.id),
                                identifier: "\(identifierPrefix)account-\(account.id.uuidString)"
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
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if !includesPeriod {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOn ? MonMonTheme.accent : MonMonTheme.textMuted)
                        .accessibilityHidden(true)
                }
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

    @ViewBuilder
    private func selectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if includesPeriod {
            content().padding(.top, 12)
        } else {
            card(content: content)
        }
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

/// An owned draft keeps Cancel and swipe-to-dismiss from changing the list.
struct TransactionFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var query: TransactionQuery
    @State private var draft: TransactionQuery
    let categories: [TransactionCategory]
    let accounts: [CashAccount]
    let resultCount: (TransactionQuery) -> Int

    init(
        query: Binding<TransactionQuery>, categories: [TransactionCategory],
        accounts: [CashAccount], resultCount: @escaping (TransactionQuery) -> Int
    ) {
        _query = query
        _draft = State(initialValue: query.wrappedValue)
        self.categories = categories
        self.accounts = accounts
        self.resultCount = resultCount
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                TransactionFilterFields(
                    query: $draft, categories: categories, accounts: accounts,
                    identifierPrefix: "spending-", includesPeriod: true, onSubmit: apply
                )
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(MonMonTheme.canvas)
            .compactRootNavigationTitle("Filters")
            .accessibilityIdentifier("spending-filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") { draft = TransactionQuery(range: .month(containing: .now)) }
                        .accessibilityIdentifier("clear-spending-filters")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    let count = resultCount(draft)
                    if count == 0 {
                        Text("No matches. Try another period or fewer filters.")
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }
                    Button(action: apply) {
                        Text("Show \(count) transactions")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.prominentAction)
                    .accessibilityIdentifier("apply-spending-filters")
                }
                .padding(16)
                .background(MonMonTheme.canvas)
            }
        }
        .tint(MonMonTheme.accent)
        .foregroundStyle(MonMonTheme.textPrimary)
        #if os(macOS)
            .frame(width: 560, height: 720)
        #else
            .presentationDetents([.large])
        #endif
    }

    private func apply() {
        query = draft
        dismiss()
    }
}
