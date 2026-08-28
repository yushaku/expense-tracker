import SwiftUI
import WidgetKit

struct QuickExpensePresetsCard: View {
    @State private var drafts: [QuickExpensePresetDraft] = []
    @State private var savedDrafts: [QuickExpensePresetDraft] = []
    @State private var statusMessage: LocalizedStringResource?

    private let store = QuickExpensePresetStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Quick expenses", systemImage: "bolt.circle.fill")
                .font(.headline)
                .foregroundStyle(MonMonTheme.accent)

            Text("Set the three expenses shown on the Home Screen widget.")
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)

            ForEach($drafts) { $draft in
                QuickExpensePresetRow(draft: $draft)

                if draft.id != drafts.last?.id {
                    Divider()
                        .overlay(MonMonTheme.border)
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
            .disabled(!isValid || drafts == savedDrafts)
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
            let loadedDrafts = store.load().map(QuickExpensePresetDraft.init)
            drafts = loadedDrafts
            savedDrafts = loadedDrafts
        }
        .onChange(of: drafts) {
            statusMessage =
                isValid ? nil : "Use one emoji and a positive whole amount for every preset."
        }
    }

    private var isValid: Bool {
        drafts.count == QuickExpenseSlot.allCases.count
            && drafts.allSatisfy { (try? $0.makePreset()) != nil }
    }

    private func save() {
        do {
            try store.save(drafts.map { try $0.makePreset() })
            savedDrafts = drafts
            statusMessage = "Saved. The widget is up to date."
            WidgetCenter.shared.reloadTimelines(ofKind: QuickExpenseWidgetConfiguration.kind)
        } catch {
            statusMessage = "Use one emoji and a positive whole amount for every preset."
        }
    }
}

private struct QuickExpensePresetRow: View {
    @Binding var draft: QuickExpensePresetDraft

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
                fields
            }

            VStack(alignment: .leading, spacing: 10) {
                title
                fields
            }
        }
    }

    private var title: some View {
        Text(draft.slot.title)
            .font(.subheadline.weight(.medium))
    }

    private var fields: some View {
        HStack(spacing: 10) {
            TextField("Emoji", text: $draft.symbol)
                .multilineTextAlignment(.center)
                .frame(minWidth: 56)
                .accessibilityLabel(Text(draft.slot.emojiFieldLabel))
                .accessibilityIdentifier("quick-expense-\(draft.slot.rawValue)-symbol")

            TextField("Amount", text: $draft.amountText)
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(minWidth: 116)
                .onChange(of: draft.amountText) {
                    let formatted = VNDCurrency.formatInput(draft.amountText)
                    if formatted != draft.amountText {
                        draft.amountText = formatted
                    }
                }
                .accessibilityLabel(Text(draft.slot.amountFieldLabel))
                .accessibilityIdentifier("quick-expense-\(draft.slot.rawValue)-amount")
        }
        .textFieldStyle(.roundedBorder)
    }
}

private extension QuickExpenseSlot {
    var title: LocalizedStringResource {
        switch self {
        case .coffee:
            "Coffee"
        case .lunch:
            "Lunch"
        case .fuel:
            "Fuel"
        }
    }

    var emojiFieldLabel: LocalizedStringResource {
        switch self {
        case .coffee:
            "Coffee emoji"
        case .lunch:
            "Lunch emoji"
        case .fuel:
            "Fuel emoji"
        }
    }

    var amountFieldLabel: LocalizedStringResource {
        switch self {
        case .coffee:
            "Coffee amount"
        case .lunch:
            "Lunch amount"
        case .fuel:
            "Fuel amount"
        }
    }
}
