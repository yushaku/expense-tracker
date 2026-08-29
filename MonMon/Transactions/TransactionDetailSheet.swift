import SwiftData
import SwiftUI

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
        VStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 58, height: 58)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityHidden(true)

            Text("\(transaction.kind.signLabel)\(VNDCurrency.format(transaction.amount))")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .foregroundStyle(
                    transaction.kind == .income ? MonMonTheme.gain : MonMonTheme.textPrimary
                )

            Text(categoryName)
                .font(.headline)
                .foregroundStyle(MonMonTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        TransactionDetailCard(
            type: transaction.kind.displayName(in: locale),
            typeImage: transaction.kind.symbolName,
            category: categoryName,
            categoryImage: symbolName,
            account: accountName,
            accountImage: account?.kind.iconName ?? "wallet.bifold",
            date: TransactionPeriod.format(Self.dateTemplate, in: locale)
                .format(transaction.occurredAt),
            trip: tripName,
            note: note
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

    private var note: String {
        let trimmed = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? AppText.string("No note", in: locale) : trimmed
    }

    private var tripName: String? {
        guard let workspaceID = transaction.tripWorkspaceID else { return nil }
        return tripWorkspaces.first { $0.id == workspaceID }?.name
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
    let type: String
    let typeImage: String
    let category: String
    let categoryImage: String
    let account: String
    let accountImage: String
    let date: String
    let trip: String?
    let note: String

    var body: some View {
        VStack(spacing: 0) {
            row(title: "Type", value: type, systemImage: typeImage)
            divider
            row(title: "Category", value: category, systemImage: categoryImage)
            divider
            row(title: "Account", value: account, systemImage: accountImage)
            divider
            row(title: "Date", value: date, systemImage: "calendar")
            if let trip {
                divider
                row(title: "Trip", value: trip, systemImage: "airplane")
            }
            divider
            row(title: "Note", value: note, systemImage: "note.text")
        }
        .padding(.horizontal, 16)
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

    private func row(
        title: LocalizedStringKey,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 34, height: 34)
                .background(
                    MonMonTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MonMonTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
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
