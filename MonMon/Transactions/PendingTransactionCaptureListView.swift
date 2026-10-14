import SwiftData
import SwiftUI

struct PendingTransactionCaptureListView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PendingTransactionCapture.createdAt, order: .reverse)
    private var captures: [PendingTransactionCapture]

    @Query private var categories: [TransactionCategory]
    @Query private var accounts: [CashAccount]

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
                        description: Text("Every captured transaction has been handled.")
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
                ToolbarItem(placement: .primaryAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .tint(MonMonTheme.textSecondary)
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
            TransactionCardContent(
                kind: capture.kind,
                amount: capture.amount,
                occurredAt: capture.occurredAt,
                note: capture.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? capture.rawText : capture.note,
                category: categories.first { $0.id == capture.categoryID },
                account: accounts.first { $0.id == capture.accountID }
            )
            .multilineTextAlignment(.leading)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Review \(capture.rawText)")
        .accessibilityIdentifier("review-capture-\(capture.id.uuidString)")
    }

}
