import SwiftUI
import WidgetKit

struct QuickExpensePresetsCard: View {
    @State private var drafts = QuickExpensePreset.defaults.map(QuickExpensePresetDraft.init)
    @State private var savedDrafts = QuickExpensePreset.defaults.map(QuickExpensePresetDraft.init)
    @State private var visibleCount: QuickExpensePresetCount = .three
    @State private var savedVisibleCount: QuickExpensePresetCount = .three
    @State private var statusMessage: LocalizedStringResource?

    private let store = QuickExpensePresetStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Quick expenses", systemImage: "bolt.circle.fill")
                .font(.headline)
                .foregroundStyle(MonMonTheme.accent)

            Text("Choose 3, 6, or 9 expenses for the Home Screen widget.")
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Presets shown")
                    .font(.subheadline.weight(.medium))

                Picker("Presets shown", selection: $visibleCount) {
                    ForEach(QuickExpensePresetCount.allCases) { count in
                        Text(count.rawValue, format: .number)
                            .tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("quick-expense-visible-count")
            }

            ForEach(visibleSlots, id: \.self) { slot in
                VStack(spacing: 16) {
                    QuickExpensePresetRow(draft: $drafts[slot.editorIndex])
                    Divider()
                        .overlay(MonMonTheme.border)
                        .opacity(slot == visibleSlots.last ? 0 : 1)
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(isValid ? MonMonTheme.textSecondary : MonMonTheme.danger)
                    .accessibilityIdentifier("quick-expense-status")
            }

            Button("Save presets", systemImage: "checkmark") {
                save()
            }
            .buttonStyle(.prominentAction)
            .disabled(!isValid || !hasChanges)
            .accessibilityIdentifier("save-quick-expense-presets")
        }
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
        .task {
            let configuration = store.load()
            let loadedDrafts = configuration.presets.map(QuickExpensePresetDraft.init)
            drafts = loadedDrafts
            savedDrafts = loadedDrafts
            visibleCount = configuration.visibleCount
            savedVisibleCount = configuration.visibleCount
        }
        .onChange(of: drafts) {
            statusMessage =
                isValid ? nil : "Use one emoji and a positive whole amount for every preset."
        }
        .onChange(of: visibleCount) {
            statusMessage =
                isValid ? nil : "Use one emoji and a positive whole amount for every preset."
        }
    }

    private var isValid: Bool {
        drafts.count == QuickExpenseSlot.allCases.count
            && drafts.prefix(visibleCount.rawValue).allSatisfy {
                (try? $0.makePreset()) != nil
            }
    }

    private var visibleSlots: ArraySlice<QuickExpenseSlot> {
        QuickExpenseSlot.allCases.prefix(visibleCount.rawValue)
    }

    private var hasChanges: Bool {
        visibleCount != savedVisibleCount
            || drafts != savedDrafts
    }

    private func save() {
        do {
            let presets = try drafts.enumerated().map { index, draft in
                if let preset = try? draft.makePreset() {
                    return preset
                }
                if index >= visibleCount.rawValue {
                    return try savedDrafts[index].makePreset()
                }
                return try draft.makePreset()
            }
            let configuration = QuickExpenseConfiguration(
                visibleCount: visibleCount,
                presets: presets
            )
            try store.save(configuration)
            let persistedDrafts = presets.map(QuickExpensePresetDraft.init)
            drafts = persistedDrafts
            savedDrafts = persistedDrafts
            savedVisibleCount = visibleCount
            statusMessage = "Saved. The widget is up to date."
            WidgetCenter.shared.reloadTimelines(ofKind: QuickExpenseWidgetConfiguration.kind)
        } catch {
            statusMessage = "Use one emoji and a positive whole amount for every preset."
        }
    }
}
