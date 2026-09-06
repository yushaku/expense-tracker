import SwiftUI

/// Inline natural-language input for the transaction editor. Applying an entry
/// only fills the draft; the editor owns validation and saving.
struct TransactionCaptureEntry: View {
    let onApply: (String) -> Void

    @State private var rawEntry = ""
    @FocusState private var isEntryFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Say it naturally", systemImage: "waveform")
                .font(.headline)

            Text("For example: 50k lunch cash yesterday")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)

            TextField("What did you spend or receive?", text: $rawEntry, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .focused($isEntryFocused)
                .submitLabel(.done)
                .onSubmit(applyEntry)
                .padding(16)
                .background(MonMonTheme.field, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("quick-capture-entry")

            Button(
                "Fill transaction details", systemImage: "text.badge.checkmark", action: applyEntry
            )
            .buttonStyle(.prominentAction)
            .disabled(rawEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("quick-capture-submit")

            Text("Review the details below, then tap Save.")
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: MonMonTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private func applyEntry() {
        guard !rawEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        isEntryFocused = false
        onApply(rawEntry)
    }
}
