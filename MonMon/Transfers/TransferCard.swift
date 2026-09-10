import SwiftData
import SwiftUI

struct TransferCard: View {
    @Environment(\.appDateFormat) private var dateFormat

    @Environment(\.locale) private var locale

    let transfer: AccountTransfer
    let sourceAccount: CashAccount?
    let destinationAccount: CashAccount?
    var showsDate = true

    var body: some View {
        HStack(spacing: 14) {
            icon

            VStack(alignment: .leading, spacing: 3) {
                Text("Internal transfer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textSecondary)
                Text(route)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            amount
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var icon: some View {
        Image(systemName: "arrow.left.arrow.right")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(MonMonTheme.accent)
            .frame(width: 44, height: 44)
            .background(MonMonTheme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))
            .accessibilityHidden(true)
    }

    /// No sign and no colour: an internal transfer is neither a gain nor a
    /// loss, and the two account names already say which way it went.
    private var amount: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(VNDCurrency.format(transfer.amount))
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(MonMonTheme.textPrimary)

            if showsDate {
                Label(
                    dateFormat.format(transfer.occurredAt),
                    systemImage: "calendar"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var route: String {
        "\(name(of: sourceAccount)) → \(name(of: destinationAccount))"
    }

    private var subtitle: String {
        transfer.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func name(of account: CashAccount?) -> String {
        account?.name ?? AppText.string("Unknown account", in: locale)
    }
}

#if DEBUG
    #Preview("Transfer cards") {
        let wallet = CashAccount.preview(name: "Wallet", kind: .normal, openingBalance: 1_250_000)
        let bank = CashAccount.preview(
            name: "Techcombank",
            kind: .normal,
            openingBalance: 48_900_000,
            createdOffset: 60
        )

        return ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 16) {
                TransferCard(
                    transfer: .preview(
                        amount: 2_000_000,
                        note: "Cash for the week",
                        sourceAccountID: bank.id,
                        destinationAccountID: wallet.id
                    ),
                    sourceAccount: bank,
                    destinationAccount: wallet
                )

                TransferCard(
                    transfer: .preview(
                        amount: 500_000,
                        sourceAccountID: wallet.id,
                        destinationAccountID: bank.id
                    ),
                    sourceAccount: wallet,
                    destinationAccount: bank
                )
            }
            .padding(20)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif

@Observable
final class TransferActions {
    var detailed: AccountTransfer?
    var editing: AccountTransfer?
    var deleteRequested: AccountTransfer?
}

/// Shares transaction gesture handling; sheets and Undo live on the screen.
struct TransferItem: View {
    @Environment(TransferActions.self) private var actions: TransferActions?
    let transfer: AccountTransfer
    let sourceAccount: CashAccount?
    let destinationAccount: CashAccount?
    var showsDate = true

    var body: some View {
        TransactionSwipeRow(
            onTap: { actions?.detailed = transfer },
            onEdit: { actions?.editing = transfer },
            onDelete: { actions?.deleteRequested = transfer }
        ) {
            TransferCard(
                transfer: transfer, sourceAccount: sourceAccount,
                destinationAccount: destinationAccount, showsDate: showsDate
            )
        }
        .accessibilityHint("Opens transfer details. Swipe left to delete or right to edit.")
    }
}

extension View {
    func transferActions(undoBottomInset: CGFloat = 20) -> some View {
        modifier(TransferActionHost(undoBottomInset: undoBottomInset))
    }
}

private struct TransferActionHost: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [CashAccount]
    @State private var actions = TransferActions()
    @State private var pendingEdit: AccountTransfer?
    @State private var undoableDeletion: DeletedTransfer?
    @State private var didFailToDelete = false
    @State private var didFailToRestore = false
    let undoBottomInset: CGFloat

    func body(content: Content) -> some View {
        content
            .environment(actions)
            .appSheet(item: $actions.detailed, onDismiss: presentPendingEditor) { transfer in
                TransferDetailSheet(
                    transfer: transfer,
                    sourceAccount: accounts.first { $0.id == transfer.sourceAccountID },
                    destinationAccount: accounts.first { $0.id == transfer.destinationAccountID },
                    onEdit: {
                        pendingEdit = transfer
                        actions.detailed = nil
                    },
                    onDelete: { try TransferDeletion.delete(transfer, from: modelContext) }
                )
            }
            .appSheet(item: $actions.editing) { transfer in
                TransferEditorView(mode: .edit(transfer))
            }
            .onChange(of: actions.deleteRequested) { _, transfer in
                guard let transfer else { return }
                actions.deleteRequested = nil
                do {
                    let snapshot = try TransferDeletion.delete(transfer, from: modelContext)
                    withAnimation(.snappy(duration: 0.28)) { undoableDeletion = snapshot }
                } catch {
                    didFailToDelete = true
                }
            }
            .overlay(alignment: .bottom) {
                if undoableDeletion != nil {
                    TransactionUndoBanner(
                        title: "Transfer deleted", identifier: "undo-delete-transfer", undo: restore
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, undoBottomInset)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: undoableDeletion?.id) {
                guard undoableDeletion != nil else { return }
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                withAnimation(.snappy(duration: 0.28)) { undoableDeletion = nil }
            }
            .alert("Couldn’t delete this transfer. Try again.", isPresented: $didFailToDelete) {
                Button("OK", role: .cancel) {}
            }
            .alert(
                "Couldn’t restore this transfer. Try adding it again.",
                isPresented: $didFailToRestore
            ) {
                Button("OK", role: .cancel) {}
            }
    }

    private func presentPendingEditor() {
        guard let transfer = pendingEdit else { return }
        pendingEdit = nil
        actions.editing = transfer
    }

    private func restore() {
        guard let snapshot = undoableDeletion else { return }
        do {
            try TransferDeletion.restore(snapshot, in: modelContext)
            withAnimation(.snappy(duration: 0.28)) { undoableDeletion = nil }
        } catch {
            undoableDeletion = nil
            didFailToRestore = true
        }
    }
}

private struct TransferDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDateFormat) private var dateFormat
    @Environment(\.locale) private var locale
    let transfer: AccountTransfer
    let sourceAccount: CashAccount?
    let destinationAccount: CashAccount?
    let onEdit: () -> Void
    let onDelete: () throws -> Void
    @State private var confirmsDelete = false
    @State private var deleteFailed = false
    @State private var selectedDetent = PresentationDetent.medium

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MonMonTheme.contentSpacing) {
                    LedgerDetailHero(
                        symbolName: "arrow.left.arrow.right",
                        tint: MonMonTheme.accent,
                        amount: VNDCurrency.format(transfer.amount),
                        subtitle:
                            "\(AppText.string("Internal transfer", in: locale)) • \(dateFormat.dateTime(transfer.occurredAt, in: locale))"
                    )
                    LedgerDetailCard {
                        accountRow("From", account: sourceAccount)
                        Divider().overlay(MonMonTheme.border)
                        accountRow("To", account: destinationAccount)
                        if let note {
                            Divider().overlay(MonMonTheme.border)
                            LedgerDetailRow(title: "Note", value: note, systemImage: "note.text")
                        }
                    }
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(MonMonTheme.canvas)
            .navigationTitle("Transfer details")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(MonMonTheme.textSecondary)
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("close-transfer-details")
                }
            }
            .navigationDestination(for: AccountDetailRoute.self) { route in
                AccountDetailView(route: route)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LedgerDetailActionBar(
                    deleteIdentifier: "delete-transfer-detail",
                    editIdentifier: "edit-transfer-detail",
                    onDelete: { confirmsDelete = true },
                    onEdit: onEdit
                )
            }
            .confirmationDialog(
                "Delete this transfer?", isPresented: $confirmsDelete, titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    do {
                        try onDelete()
                        dismiss()
                    } catch { deleteFailed = true }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Both account balances return to what they were.")
            }
            .alert("Couldn’t delete this transfer. Try again.", isPresented: $deleteFailed) {
                Button("OK", role: .cancel) {}
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("transfer-details")
    }

    private var note: String? {
        let trimmed = transfer.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @ViewBuilder
    private func accountRow(_ title: LocalizedStringKey, account: CashAccount?) -> some View {
        if let account {
            NavigationLink(value: AccountDetailRoute(accountID: account.id)) {
                LedgerDetailRow(
                    title: title, value: account.name,
                    systemImage: account.kind.iconName, showsDisclosure: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens linked details")
        } else {
            LedgerDetailRow(
                title: title, value: AppText.string("Unknown account", in: locale),
                systemImage: "wallet.bifold"
            )
        }
    }
}
