import SwiftUI

/// Asks where a category's records — the transactions already recorded under
/// it and the recurring rules that would record more — should go before it is
/// deleted. The caller performs the move and the deletion together, so
/// cancelling here leaves both the category and its records untouched.
struct CategoryReassignView: View {
    @Environment(\.dismiss) private var dismiss

    let category: TransactionCategory
    let usageCount: Int
    let replacements: [TransactionCategory]
    let errorMessage: String?
    let onConfirm: (TransactionCategory) -> Void

    @State private var replacementID: UUID?

    var body: some View {
        #if os(macOS)
            form
                .frame(minWidth: 420, minHeight: 420)
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
                        introduction
                        replacementCard

                        if let errorMessage {
                            errorBanner(errorMessage)
                        }
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Move records")
            .accessibilityIdentifier("reassign-category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Move and delete") {
                        confirm()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedReplacement == nil)
                    .accessibilityIdentifier("confirm-reassign-category")
                }
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
        .onAppear {
            if replacementID == nil {
                replacementID = replacements.first?.id
            }
        }
    }

    private var introduction: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.trianglehead.branch")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(MonMonTheme.danger, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Give them a new home")
                    .font(.title3.weight(.semibold))

                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var explanation: String {
        let noun = usageCount == 1 ? "record" : "records"
        return "\(usageCount) \(noun) use \(category.name). Pick where they move to."
    }

    private var replacementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Move to", systemImage: "tag.fill")
                .font(.headline)

            Picker("Move to", selection: $replacementID) {
                ForEach(replacements) { replacement in
                    Text(replacement.name)
                        .tag(UUID?.some(replacement.id))
                }
            }
            .labelsHidden()
            .accessibilityIdentifier("reassign-target")

            Text("Only \(category.kind.displayName.lowercased()) categories are offered.")
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
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
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                MonMonTheme.danger.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MonMonTheme.danger.opacity(0.35), lineWidth: 1)
            }
            .accessibilityIdentifier("reassign-category-error")
    }

    private var selectedReplacement: TransactionCategory? {
        guard let replacementID else {
            return nil
        }

        return replacements.first { $0.id == replacementID }
    }

    private func confirm() {
        guard let selectedReplacement else {
            return
        }

        onConfirm(selectedReplacement)
    }
}
