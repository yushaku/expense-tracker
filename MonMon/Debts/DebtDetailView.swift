import SwiftData
import SwiftUI

/// One debt and the payments recorded against it. A debt is the only record in
/// this app with children, so tapping its card shows them rather than opening an
/// editor.
struct DebtDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Debt.createdAt, order: .forward)
    private var debts: [Debt]

    @Query(sort: \DebtPayment.occurredAt, order: .reverse)
    private var payments: [DebtPayment]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    private let route: DebtRoute
    private let asOf: Date

    @State private var editorMode: DebtEditorMode?
    @State private var paymentEditorMode: DebtPaymentEditorMode?

    init(route: DebtRoute, asOf: Date = .now) {
        self.route = route
        self.asOf = asOf
    }

    /// Re-queried here rather than passed along, so this screen stays right when
    /// the debt is edited from it — and goes `nil` when the debt is deleted.
    private var debt: Debt? {
        debts.first { $0.id == route.debtID }
    }

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            if let debt {
                content(for: debt)
            }
        }
        .navigationTitle(debt?.counterparty ?? "Debt")
        .accessibilityIdentifier("debt-detail")
        .toolbar {
            if let debt {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit", systemImage: "pencil") {
                        editorMode = .edit(debt)
                    }
                    .accessibilityIdentifier("edit-debt")
                }
            }
        }
        .appSheet(item: $editorMode) { mode in
            DebtEditorView(mode: mode)
        }
        .appSheet(item: $paymentEditorMode) { mode in
            if let debt {
                DebtPaymentEditorView(mode: mode, debt: debt)
            }
        }
        .onChange(of: debt == nil) { _, isGone in
            // A pushed screen holding a deleted model traps on the next property
            // read, so it leaves as soon as its debt does.
            if isGone {
                dismiss()
            }
        }
        .tint(MonMonTheme.accent)
    }

    private func content(for debt: Debt) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                DebtCard(
                    debt: debt,
                    outstanding: outstanding(for: debt),
                    paid: DebtSummary.paid(for: debt, payments: payments),
                    progress: DebtSummary.progress(for: debt, payments: payments),
                    accountName: accountName(debt.accountID),
                    isOverdue: DebtSummary.isOverdue(debt, payments: payments, asOf: asOf),
                    projectedInterest: debt.projectedInterest(asOf: asOf)
                )

                if recordedPayments(for: debt).isEmpty {
                    emptyState(for: debt)
                } else {
                    paymentsSection(for: debt)
                }
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, FloatingAddButton.contentInset)
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .bottomTrailing) {
            if !recordedPayments(for: debt).isEmpty {
                addPaymentButton(for: debt)
            }
        }
    }

    private func addPaymentButton(for debt: Debt) -> some View {
        FloatingAddButton(
            title: "Record Payment",
            accessibilityIdentifier: "add-debt-payment"
        ) {
            paymentEditorMode = .add(debt)
        }
    }

    private func paymentsSection(for debt: Debt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Payments")
                    .font(.title3.weight(.semibold))

                Text("\(recordedPayments(for: debt).count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(debt.direction.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(debt.direction.tint.opacity(0.16), in: Capsule())
            }

            ForEach(recordedPayments(for: debt)) { payment in
                Button {
                    paymentEditorMode = .edit(payment)
                } label: {
                    DebtPaymentCard(
                        payment: payment,
                        direction: debt.direction,
                        accountName: accountName(payment.accountID)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("debt-payment-\(payment.id.uuidString)")
                .accessibilityHint("Opens the payment editor.")
            }
        }
    }

    private func emptyState(for debt: Debt) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "tray.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.accent)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("No payments yet")
                    .font(.title3.weight(.semibold))

                Text("Every payment moves this account and lowers what is outstanding.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button("Record Payment", systemImage: "plus") {
                paymentEditorMode = .add(debt)
            }
            .buttonStyle(.prominentAction)
            .accessibilityIdentifier("add-debt-payment")
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

    private func recordedPayments(for debt: Debt) -> [DebtPayment] {
        DebtSummary.payments(for: debt, payments: payments)
    }

    private func outstanding(for debt: Debt) -> Decimal {
        DebtSummary.outstanding(for: debt, payments: payments)
    }

    private func accountName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }?.name
    }
}
