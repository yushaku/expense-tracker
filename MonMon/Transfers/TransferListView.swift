import SwiftData
import SwiftUI

struct TransferListView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \AccountTransfer.occurredAt, order: .reverse)
    private var transfers: [AccountTransfer]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @State private var editorMode: TransferEditorMode?

    var body: some View {
        #if os(macOS)
            list
                .frame(minWidth: 460, minHeight: 600)
        #else
            list
        #endif
    }

    private var list: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        if accounts.count < 2 {
                            tooFewAccountsState
                        } else if transfers.isEmpty {
                            emptyState
                        } else {
                            totalCard

                            transfersSection
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Transfers")
            .accessibilityIdentifier("transfer-list")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if accounts.count >= 2 {
                    ToolbarItem(placement: .primaryAction) {
                        addTransferButton
                    }
                }
            }
            .sheet(item: $editorMode) { mode in
                TransferEditorView(mode: mode)
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private var addTransferButton: some View {
        Button("Add Transfer", systemImage: "plus") {
            editorMode = .add
        }
        .accessibilityIdentifier("add-transfer")
    }

    /// Money moved, not money made: the total is what passed between accounts,
    /// which is why it sits apart from the Spending screen's income and expense.
    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("MOVED BETWEEN ACCOUNTS", systemImage: "arrow.left.arrow.right")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(VNDCurrency.format(TransferSummary.total(of: transfers)))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(MonMonTheme.textPrimary)

            Label(countLabel, systemImage: "rectangle.stack.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.hero)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.heroBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var countLabel: String {
        transfers.count == 1 ? "1 transfer" : "\(transfers.count) transfers"
    }

    private var transfersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.title3.weight(.semibold))

            ForEach(transfers) { transfer in
                Button {
                    editorMode = .edit(transfer)
                } label: {
                    TransferCard(
                        transfer: transfer,
                        sourceAccount: account(transfer.sourceAccountID),
                        destinationAccount: account(transfer.destinationAccountID)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("transfer-\(transfer.id.uuidString)")
                .accessibilityHint("Opens the transfer editor.")
            }
        }
    }

    private func account(_ id: UUID) -> CashAccount? {
        accounts.first { $0.id == id }
    }

    private var emptyState: some View {
        placeholder(
            title: "Nothing moved yet",
            message: "Record money you shifted between your own accounts. "
                + "Your total assets stay the same."
        ) {
            addTransferButton
        }
    }

    private var tooFewAccountsState: some View {
        placeholder(
            title: "Add a second account first",
            message: "A transfer needs somewhere to leave and somewhere to land."
        ) {
            EmptyView()
        }
    }

    private func placeholder<Action: View>(
        title: String,
        message: String,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            action()
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }
}

#if DEBUG
    #Preview("Transfers") {
        TransferListView()
            .modelContainer(PreviewData.populated)
    }
#endif
