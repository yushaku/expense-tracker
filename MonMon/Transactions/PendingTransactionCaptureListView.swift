import SwiftData
import SwiftUI

struct PendingTransactionCaptureListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PendingTransactionCapture.createdAt, order: .reverse)
    private var captures: [PendingTransactionCapture]

    @Query private var categories: [TransactionCategory]
    @Query private var accounts: [CashAccount]

    @State private var selectedCapture: PendingTransactionCapture?
    @State private var undoableDeletion: DeletedPendingCapture?
    @State private var didFailToDelete = false
    @State private var didFailToRestore = false

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
                                captureItem(capture)
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
            .safeAreaInset(edge: .bottom) {
                if undoableDeletion != nil {
                    TransactionUndoBanner(
                        identifier: "undo-delete-capture", undo: restore
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: undoableDeletion?.id) {
                guard undoableDeletion != nil else { return }
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                withAnimation(.snappy(duration: 0.28)) { undoableDeletion = nil }
            }
            .alert("Couldn’t delete this transaction. Try again.", isPresented: $didFailToDelete) {
                Button("OK", role: .cancel) {}
            }
            .alert(
                "Couldn’t restore this transaction. Try adding it again.",
                isPresented: $didFailToRestore
            ) {
                Button("OK", role: .cancel) {}
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private func captureItem(_ capture: PendingTransactionCapture) -> some View {
        TransactionSwipeRow(
            onTap: { selectedCapture = capture },
            onEdit: { selectedCapture = capture },
            onDelete: { delete(capture) }
        ) {
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
        .accessibilityLabel("Review \(capture.rawText)")
        .accessibilityIdentifier("review-capture-\(capture.id.uuidString)")
    }

    private func delete(_ capture: PendingTransactionCapture) {
        do {
            let snapshot = try PendingCaptureDeletion.delete(capture, from: modelContext)
            withAnimation(.snappy(duration: 0.28)) { undoableDeletion = snapshot }
        } catch {
            didFailToDelete = true
        }
    }

    private func restore() {
        guard let snapshot = undoableDeletion else { return }
        do {
            try PendingCaptureDeletion.restore(snapshot, in: modelContext)
            withAnimation(.snappy(duration: 0.28)) { undoableDeletion = nil }
        } catch {
            undoableDeletion = nil
            didFailToRestore = true
        }
    }
}
