import SwiftUI

struct DebtPaymentCard: View {
    let payment: DebtPayment
    let direction: DebtDirection
    let accountName: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(direction.tint)
                .frame(width: 40, height: 40)
                .background(
                    direction.tint.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(payment.occurredAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            // The sign is the account's, not the debt's: repaying takes money
            // out, being repaid puts it back.
            Text("\(signLabel)\(VNDCurrency.format(payment.amount))")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(direction.tint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var symbolName: String {
        direction == .borrowed ? "arrow.up.right" : "arrow.down.left"
    }

    private var signLabel: String {
        direction == .borrowed ? "−" : "+"
    }

    private var subtitle: String {
        let note = payment.note.isEmpty ? nil : payment.note
        let account = accountName.map { direction == .borrowed ? "From \($0)" : "Into \($0)" }

        return [account, note].compactMap { $0 }.joined(separator: " · ")
    }
}

#if DEBUG
    #Preview("Payment cards") {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            VStack(spacing: 12) {
                DebtPaymentCard(
                    payment: .preview(
                        debtID: UUID(),
                        amount: 5_000_000,
                        accountID: UUID(),
                        note: "First instalment"
                    ),
                    direction: .borrowed,
                    accountName: "Techcombank"
                )

                DebtPaymentCard(
                    payment: .preview(debtID: UUID(), amount: 2_000_000, accountID: UUID()),
                    direction: .lent,
                    accountName: "Wallet"
                )
            }
            .padding(20)
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
