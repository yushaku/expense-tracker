import SwiftData
import SwiftUI

struct TransactionDetailLinks: Equatable {
    var categoryID: UUID? = nil
    var accountID: UUID? = nil
    var tripWorkspaceID: UUID? = nil

    static func resolve(
        transaction: MoneyTransaction,
        categoryID: UUID?,
        accountID: UUID?,
        availableTripIDs: Set<UUID>
    ) -> TransactionDetailLinks {
        TransactionDetailLinks(
            categoryID: categoryID == transaction.categoryID ? categoryID : nil,
            accountID: accountID == transaction.accountID ? accountID : nil,
            tripWorkspaceID: transaction.tripWorkspaceID.flatMap {
                availableTripIDs.contains($0) ? $0 : nil
            }
        )
    }
}

private enum TransactionDetailDestination: Hashable {
    case account(UUID)
    case trip(UUID)
}

/// A quick read of one transaction list item. Editing remains in the full
/// editor; this sheet is read-only so a tap never changes money by accident.
struct TransactionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Query(sort: \TripWorkspace.startedAt, order: .reverse)
    private var tripWorkspaces: [TripWorkspace]

    let transaction: MoneyTransaction
    let category: TransactionCategory?
    let account: CashAccount?
    let onEdit: () -> Void
    let onDelete: () throws -> Void

    @State private var isConfirmingDelete = false
    @State private var isShowingDeleteError = false
    @State private var categoryEditorMode: CategoryEditorMode?

    private static let dateTemplate = Date.FormatStyle()
        .weekday(.wide)
        .day()
        .month(.wide)
        .year()
        .hour()
        .minute()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MonMonTheme.contentSpacing) {
                    hero
                    details
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
            }
            // In a sheet, a scroll view that bounces eats the start of a drag
            // downwards before the sheet begins to move, so leaving takes two
            // pulls where it should take one. Content that already fits has
            // nothing to scroll and so has no reason to bounce.
            .scrollBounceBehavior(.basedOnSize)
            .background(MonMonTheme.canvas)
            .navigationTitle("Transaction details")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("close-transaction-details")
                }
            }
            .navigationDestination(for: TransactionDetailDestination.self) { destination in
                switch destination {
                case .account(let accountID):
                    AccountDetailView(route: AccountDetailRoute(accountID: accountID))
                case .trip(let workspaceID):
                    if let workspace = tripWorkspaces.first(where: { $0.id == workspaceID }) {
                        TripDetailView(workspace: workspace)
                    } else {
                        ContentUnavailableView(
                            "Trip unavailable",
                            systemImage: "airplane",
                            description: Text("This trip is no longer in the current store.")
                        )
                    }
                }
            }
            .appSheet(item: $categoryEditorMode) { mode in
                CategoryEditorView(mode: mode)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actions
            }
            .confirmationDialog(
                "Delete this transaction?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    delete()
                }
                .accessibilityIdentifier("confirm-delete-transaction-detail")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its account balance returns to what it was.")
            }
            .alert(
                "Couldn’t delete this transaction. Try again.",
                isPresented: $isShowingDeleteError
            ) {
                Button("OK", role: .cancel) {}
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
        // One height, so a drag downwards leaves in one motion rather than
        // stopping halfway at a second one.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("transaction-details")
    }

    private var hero: some View {
        HStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(transaction.kind.signLabel)\(VNDCurrency.format(transaction.amount))")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
                    .foregroundStyle(
                        transaction.kind == .income ? MonMonTheme.gain : MonMonTheme.textPrimary
                    )

                Text("\(transaction.kind.displayName(in: locale)) • \(formattedDate)")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        TransactionDetailCard(
            category: categoryName,
            categoryImage: symbolName,
            account: accountName,
            accountImage: account?.kind.iconName ?? "wallet.bifold",
            trip: tripName,
            note: note,
            onOpenCategory: links.categoryID == nil
                ? nil
                : {
                    if let category {
                        categoryEditorMode = .edit(category)
                    }
                },
            accountDestination: links.accountID.map(TransactionDetailDestination.account),
            tripDestination: links.tripWorkspaceID.map(TransactionDetailDestination.trip)
        )
    }

    private var actions: some View {
        TransactionDetailActionBar(
            onDelete: {
                isConfirmingDelete = true
            },
            onEdit: onEdit
        )
    }

    private var categoryName: String {
        category?.name ?? AppText.string("Uncategorized", in: locale)
    }

    private var accountName: String {
        account?.name ?? AppText.string("Unknown account", in: locale)
    }

    private var note: String? {
        let trimmed = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var tripName: String? {
        guard let workspaceID = transaction.tripWorkspaceID else { return nil }
        return tripWorkspaces.first { $0.id == workspaceID }?.name
    }

    private var formattedDate: String {
        TransactionPeriod.format(Self.dateTemplate, in: locale).format(transaction.occurredAt)
    }

    private var links: TransactionDetailLinks {
        TransactionDetailLinks.resolve(
            transaction: transaction,
            categoryID: category?.id,
            accountID: account?.id,
            availableTripIDs: Set(tripWorkspaces.map(\.id))
        )
    }

    private var symbolName: String {
        category.map { CategoryPalette.symbolName($0.symbolName) } ?? transaction.kind.symbolName
    }

    private var tint: Color {
        category.map { CategoryPalette.color(named: $0.colorName) } ?? MonMonTheme.textMuted
    }

    private func delete() {
        do {
            try onDelete()
            dismiss()
        } catch {
            isShowingDeleteError = true
        }
    }
}

private struct TransactionDetailCard: View {
    let category: String
    let categoryImage: String
    let account: String
    let accountImage: String
    let trip: String?
    let note: String?
    let onOpenCategory: (() -> Void)?
    let accountDestination: TransactionDetailDestination?
    let tripDestination: TransactionDetailDestination?

    var body: some View {
        VStack(spacing: 0) {
            linkedRow(
                title: "Category",
                value: category,
                systemImage: categoryImage,
                action: onOpenCategory
            )
            divider
            destinationRow(
                title: "Account",
                value: account,
                systemImage: accountImage,
                destination: accountDestination
            )
            if let trip {
                divider
                destinationRow(
                    title: "Trip",
                    value: trip,
                    systemImage: "airplane",
                    destination: tripDestination
                )
            }
            if let note {
                divider
                rowContent(
                    title: "Note",
                    value: note,
                    systemImage: "note.text",
                    showsDisclosure: false
                )
            }
        }
        .padding(.horizontal, 14)
        .background(MonMonTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private var divider: some View {
        Divider().overlay(MonMonTheme.border)
    }

    @ViewBuilder
    private func linkedRow(
        title: LocalizedStringKey,
        value: String,
        systemImage: String,
        action: (() -> Void)?
    ) -> some View {
        if let action {
            Button(action: action) {
                rowContent(
                    title: title,
                    value: value,
                    systemImage: systemImage,
                    showsDisclosure: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this category")
        } else {
            rowContent(
                title: title,
                value: value,
                systemImage: systemImage,
                showsDisclosure: false
            )
        }
    }

    @ViewBuilder
    private func destinationRow(
        title: LocalizedStringKey,
        value: String,
        systemImage: String,
        destination: TransactionDetailDestination?
    ) -> some View {
        if let destination {
            NavigationLink(value: destination) {
                rowContent(
                    title: title,
                    value: value,
                    systemImage: systemImage,
                    showsDisclosure: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens linked details")
        } else {
            rowContent(
                title: title,
                value: value,
                systemImage: systemImage,
                showsDisclosure: false
            )
        }
    }

    private func rowContent(
        title: LocalizedStringKey,
        value: String,
        systemImage: String,
        showsDisclosure: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MonMonTheme.textPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct TransactionDetailActionBar: View {
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(MonMonTheme.danger)
                    .background(MonMonTheme.danger.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("delete-report-transaction")

            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
                    .frame(maxWidth: .infinity, minHeight: 20)
            }
            .buttonStyle(.prominentAction)
            .accessibilityIdentifier("edit-report-transaction")
        }
        .frame(maxWidth: MonMonTheme.maxContentWidth)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(MonMonTheme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MonMonTheme.border)
                .frame(height: 1)
        }
    }
}
