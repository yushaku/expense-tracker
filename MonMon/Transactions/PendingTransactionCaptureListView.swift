import SwiftData
import SwiftUI

struct PendingTransactionCaptureListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Query(sort: \PendingTransactionCapture.createdAt, order: .reverse)
    private var captures: [PendingTransactionCapture]

    @State private var selectedCapture: PendingTransactionCapture?

    var body: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                if captures.isEmpty {
                    ContentUnavailableView(
                        "Nothing to review",
                        systemImage: "checkmark.circle.fill",
                        description: Text("Every spoken transaction has been handled.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(captures) { capture in
                                captureButton(capture)
                            }
                        }
                        .frame(maxWidth: MonMonTheme.maxContentWidth)
                        .padding(20)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Needs review")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .appSheet(item: $selectedCapture) { capture in
                TransactionEditorView(mode: .review(capture))
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private func captureButton(_ capture: PendingTransactionCapture) -> some View {
        Button {
            selectedCapture = capture
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "waveform.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(MonMonTheme.credit)
                    .frame(width: 44, height: 44)
                    .background(
                        MonMonTheme.credit.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(capture.rawText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(captureSummary(capture))
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textMuted)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Review \(capture.rawText)")
        .accessibilityIdentifier("review-capture-\(capture.id.uuidString)")
    }

    private func captureSummary(_ capture: PendingTransactionCapture) -> String {
        var parts: [String] = []
        if let amount = capture.amount {
            parts.append(VNDCurrency.format(amount))
        } else {
            parts.append(AppText.string("Amount missing", in: locale))
        }
        parts.append(capture.kind.displayName(in: locale))
        return parts.joined(separator: " · ")
    }
}
