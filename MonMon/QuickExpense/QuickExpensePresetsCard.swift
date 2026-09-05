import SwiftData
import SwiftUI
import WidgetKit

struct QuickExpensePresetsCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]
    @AppStorage(TransactionDefaults.categoryStorageKey)
    private var defaultExpenseCategoryValue = ""

    @AppStorage(
        QuickExpensePresetStore.storageKey,
        store: QuickExpenseWidgetConfiguration.makeDefaults()
    ) private var storedPresets = Data()

    @State private var configuration = QuickExpenseConfiguration.defaults
    @State private var selectedPreset: QuickExpensePreset?
    @State private var saveFailed = false
    @State private var didSaveCount = false

    private let store = QuickExpensePresetStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Quick expenses", systemImage: "bolt.fill")
                .font(.headline)
            Text("Tap a preset to edit its name, amount, and category.")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)

            QuickExpenseAccountSummary()

            VStack(alignment: .leading, spacing: 8) {
                Text("Presets shown")
                    .font(.subheadline.weight(.medium))
                Picker("Presets shown", selection: countSelection) {
                    ForEach(QuickExpensePresetCount.allCases) { count in
                        Text(count.rawValue, format: .number).tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("quick-expense-visible-count")
                Text("Widget limits: small 3 · medium 6 · large 9. Hidden presets are kept.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(configuration.activePresets) { preset in
                    Button {
                        selectedPreset = preset
                    } label: {
                        QuickExpensePresetTile(
                            symbol: preset.symbol,
                            amount: preset.amount,
                            category: resolvedCategory(for: preset),
                            usesDefault: preset.categoryID == nil,
                            showsEditIndicator: true
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit this preset. No expense will be recorded.")
                    .accessibilityIdentifier("edit-quick-expense-\(preset.slot.rawValue)")
                }
            }

            if saveFailed {
                Label("Couldn’t save presets. Try again.", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.danger)
                    .accessibilityIdentifier("quick-expense-status")
            } else if didSaveCount {
                Label("Saved. The widget is up to date.", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .accessibilityIdentifier("quick-expense-status")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(MonMonTheme.surface, in: .rect(cornerRadius: MonMonTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .task { reload() }
        .onChange(of: storedPresets) { reload() }
        .appSheet(item: $selectedPreset, onDismiss: reload) { preset in
            QuickExpensePresetEditor(preset: preset)
        }
    }

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 140), spacing: 12)]
    }

    private var countSelection: Binding<QuickExpensePresetCount> {
        Binding(get: { configuration.visibleCount }, set: { saveCount($0) })
    }

    private func resolvedCategory(for preset: QuickExpensePreset) -> TransactionCategory? {
        let id = TransactionDefaults.resolveCategoryID(
            preset.categoryID?.uuidString ?? defaultExpenseCategoryValue,
            categories: categories
        )
        return categories.first { $0.id == id && $0.kind == .expense }
    }

    private func reload() {
        configuration = store.load()
    }

    private func saveCount(_ count: QuickExpensePresetCount) {
        do {
            try store.setVisibleCount(count)
            reload()
            saveFailed = false
            didSaveCount = true
            WidgetCenter.shared.reloadTimelines(ofKind: QuickExpenseWidgetConfiguration.kind)
        } catch {
            saveFailed = true
        }
    }
}

struct QuickExpensePresetTile: View {
    let symbol: String
    let amount: Decimal?
    let category: TransactionCategory?
    let usesDefault: Bool
    var showsEditIndicator = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(verbatim: symbol.isEmpty ? "—" : symbol)
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showsEditIndicator {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            Text(verbatim: amount.map { VNDCurrency.formatPlain($0) + " ₫" } ?? "—")
                .font(.headline)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            if let category {
                Label {
                    Text(verbatim: category.name)
                } icon: {
                    Image(systemName: CategoryPalette.symbolName(category.symbolName))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(MonMonTheme.textSecondary)
            } else {
                Label("Choose a category", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.danger)
            }
            if usesDefault {
                Text("Uses transaction default")
                    .font(.caption2)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(MonMonTheme.hero, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(MonMonTheme.heroBorder, lineWidth: 1)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .accessibilityElement(children: .combine)
    }
}

struct QuickExpenseAccountSummary: View {
    @Query private var accounts: [CashAccount]
    @AppStorage(TransactionDefaults.accountStorageKey) private var defaultAccountValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let account {
                Text("Records to account")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                Label {
                    Text(verbatim: account.name)
                } icon: {
                    Image(systemName: "wallet.bifold")
                }
                .font(.subheadline.weight(.medium))
            } else {
                Label("Choose a default account", systemImage: "exclamationmark.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MonMonTheme.danger)
                Text("Choose an account in Defaults before using the widget.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(MonMonTheme.field, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var account: CashAccount? {
        let id = TransactionDefaults.resolveAccountID(defaultAccountValue, accounts: accounts)
        return accounts.first { $0.id == id }
    }
}
