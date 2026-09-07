import CoreTransferable
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

struct QuickExpensePresetsCard: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var didSave = false
    @State private var reorderSessionID = UUID()

    private let store = QuickExpensePresetStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Quick expenses", systemImage: "bolt.fill")
                .font(.headline)
            Text(
                "Tap to edit a preset. Touch and hold, then drag onto another preset to change its position."
            )
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.textSecondary)

            QuickExpenseAccountSummary()

            VStack(alignment: .leading, spacing: 8) {
                Text("Presets shown")
                    .font(.subheadline.weight(.medium))
                Stepper(
                    value: countSelection,
                    in: QuickExpenseConfiguration.countRange
                ) {
                    Text(configuration.visibleCount, format: .number)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                .accessibilityIdentifier("quick-expense-visible-count")
                .accessibilityLabel("Presets shown")

                Text(widgetCapacityCaption)
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
                    .modifier(
                        QuickExpenseReorderDrag(
                            item: QuickExpenseDragItem(
                                slot: preset.slot, sessionID: reorderSessionID),
                            move: { source in movePreset(source, to: preset.slot) }
                        )
                    )
                    .accessibilityActions {
                        if preset.slot != configuration.activePresets.first?.slot {
                            Button("Move earlier") { movePreset(preset.slot, offset: -1) }
                        }
                        if preset.slot != configuration.activePresets.last?.slot {
                            Button("Move later") { movePreset(preset.slot, offset: 1) }
                        }
                    }
                }
            }

            if saveFailed {
                Label("Couldn’t save presets. Try again.", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.danger)
                    .accessibilityIdentifier("quick-expense-status")
            } else if didSave {
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

    private var countSelection: Binding<Int> {
        Binding(get: { configuration.visibleCount }, set: { saveCount($0) })
    }

    /// What each widget size can hold, read off the layout rather than typed
    /// out, so the sentence cannot drift from what the widget draws.
    private var widgetCapacityCaption: String {
        let sizes = QuickExpenseWidgetLayout.Size.allCases.map { size in
            let name = AppText.string(key: size.displayNameKey, in: locale)
            return "\(name) \(QuickExpenseWidgetLayout.capacity(size))"
        }
        .joined(separator: " · ")

        let limits = AppText.string("Widget sizes hold:", in: locale)
        let kept = AppText.string(
            "A size shows as many as it fits. Hidden presets are kept.",
            in: locale
        )
        return "\(limits) \(sizes). \(kept)"
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

    private func movePreset(_ slot: QuickExpenseSlot, offset: Int) {
        let visible = store.load().activePresets
        guard let index = visible.firstIndex(where: { $0.slot == slot }),
            visible.indices.contains(index + offset)
        else { return }
        _ = movePreset(slot, to: visible[index + offset].slot)
    }

    private func movePreset(_ slot: QuickExpenseSlot, to target: QuickExpenseSlot) -> Bool {
        do {
            guard try store.movePreset(slot, to: target) else { return false }
            withAnimation(reduceMotion ? nil : .snappy) { reload() }
            saveFailed = false
            didSave = true
            WidgetCenter.shared.reloadTimelines(ofKind: QuickExpenseWidgetConfiguration.kind)
            return true
        } catch {
            saveFailed = true
            return false
        }
    }

    private func saveCount(_ count: Int) {
        do {
            try store.setVisibleCount(count)
            reload()
            saveFailed = false
            didSave = true
            WidgetCenter.shared.reloadTimelines(ofKind: QuickExpenseWidgetConfiguration.kind)
        } catch {
            saveFailed = true
        }
    }
}

private struct QuickExpenseDragItem: Codable, Transferable {
    let slot: QuickExpenseSlot
    let sessionID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: UTType(exportedAs: "com.monmon.quick-expense-position"))
    }
}

private struct QuickExpenseReorderDrag: ViewModifier {
    let item: QuickExpenseDragItem
    let move: (QuickExpenseSlot) -> Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content
                .draggable(item)
                .dropDestination(for: QuickExpenseDragItem.self, isEnabled: true) { items, _ in
                    _ = accept(items)
                }
        } else {
            // Compatibility path for OS versions without DropSession.
            content
                .draggable(item)
                .dropDestination(for: QuickExpenseDragItem.self) { items, _ in
                    accept(items)
                }
        }
    }

    private func accept(_ items: [QuickExpenseDragItem]) -> Bool {
        // Only reorder inside this card; a drop from another app/window must
        // not reinterpret its slot as one of this device's presets.
        guard items.count == 1, let source = items.first,
            source.sessionID == item.sessionID
        else { return false }
        return move(source.slot)
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
