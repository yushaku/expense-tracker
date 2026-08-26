import SwiftData
import SwiftUI

struct QuickTransactionCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    private let launchMode: QuickCaptureLaunchMode

    @State private var rawEntry = ""
    @State private var preparedCapture: ParsedTransactionCapture?
    @State private var isConfirming = false
    @State private var errorMessage: LocalizedStringKey?
    @FocusState private var isEntryFocused: Bool

    init(launchMode: QuickCaptureLaunchMode = .keyboard) {
        self.launchMode = launchMode
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        introduction
                        entryCard

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(MonMonTheme.danger)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    MonMonTheme.danger.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                        }
                    }
                    .frame(maxWidth: 560)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Quick capture")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                confirmationTitle,
                isPresented: $isConfirming,
                titleVisibility: .visible
            ) {
                Button(confirmButtonTitle) { commitPreparedCapture() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(confirmationMessage)
            }
            .task { isEntryFocused = launchMode == .keyboard }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private var introduction: some View {
        HStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(MonMonTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Say it naturally")
                    .font(.title3.weight(.semibold))

                Text("For example: 50k lunch cash yesterday")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var entryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if launchMode == .voice {
                VoiceTransactionCaptureSection(transcript: $rawEntry)
            }

            TextField("What did you spend or receive?", text: $rawEntry, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .focused($isEntryFocused)
                .submitLabel(.done)
                .onSubmit(prepareCapture)
                .padding(16)
                .background(
                    MonMonTheme.field,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .accessibilityIdentifier("quick-capture-entry")

            Button("Review & save", systemImage: "checkmark.circle.fill", action: prepareCapture)
                .buttonStyle(.prominentAction)
                .disabled(rawEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("quick-capture-submit")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: MonMonTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private func prepareCapture() {
        errorMessage = nil
        do {
            preparedCapture = try TransactionCaptureService(container: modelContext.container)
                .prepare(rawEntry)
            isConfirming = true
        } catch {
            errorMessage = "Couldn’t understand that entry. Try again."
        }
    }

    private func commitPreparedCapture() {
        guard let preparedCapture else {
            return
        }

        do {
            _ = try TransactionCaptureService(container: modelContext.container)
                .commit(preparedCapture)
            dismiss()
        } catch {
            errorMessage = "Couldn’t save that entry. Try again."
        }
    }

    private var confirmationTitle: LocalizedStringKey {
        preparedCapture?.isReady == true ? "Save this transaction?" : "Save for review?"
    }

    private var confirmButtonTitle: LocalizedStringKey {
        preparedCapture?.isReady == true ? "Save transaction" : "Save for review"
    }

    private var confirmationMessage: String {
        guard let capture = preparedCapture else {
            return ""
        }
        if let amount = capture.amount {
            return "\(capture.kind.displayName(in: locale)) · \(VNDCurrency.format(amount))"
        }
        return AppText.string("Missing details will stay in Needs review.", in: locale)
    }
}
