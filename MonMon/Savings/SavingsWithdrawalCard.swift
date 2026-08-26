import SwiftUI

struct SavingsWithdrawalCard: View {
    @Environment(\.locale) private var locale

    let withdrawal: SavingsWithdrawal
    let destinationAccountName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.to.line")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.savings)
                    .frame(width: 32, height: 32)
                    .background(MonMonTheme.savings.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(VNDCurrency.format(withdrawal.principal))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(VNDCurrency.format(withdrawal.amountReceived))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()

                    Text(interestDescription)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            withdrawal.realizedInterest >= 0
                                ? MonMonTheme.gain : MonMonTheme.danger
                        )
                }
            }

            if !withdrawal.note.isEmpty {
                Text(withdrawal.note)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
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

    private var subtitle: String {
        let day = TransactionPeriod.day(withdrawal.withdrawnAt, in: locale)
        guard let destinationAccountName else { return day }
        let into = AppText.string("into", in: locale)
        return "\(day) · \(into) \(destinationAccountName)"
    }

    private var interestDescription: String {
        let value = withdrawal.realizedInterest
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(VNDCurrency.format(abs(value)))"
    }
}
