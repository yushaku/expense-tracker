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
