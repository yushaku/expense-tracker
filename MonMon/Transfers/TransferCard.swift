import SwiftUI

struct TransferCard: View {
    @Environment(\.locale) private var locale

    let transfer: AccountTransfer
    let sourceAccount: CashAccount?
    let destinationAccount: CashAccount?

    private static let dateFormat: Date.FormatStyle = {
        var style = Date.FormatStyle().day().month(.abbreviated)
        style.calendar = TransactionPeriod.calendar
        style.timeZone = TransactionPeriod.calendar.timeZone
        style.locale = Locale(identifier: "en_US")
        return style
    }()

    var body: some View {
        HStack(spacing: 14) {
            icon

            VStack(alignment: .leading, spacing: 3) {
                Text(route)
                    .font(.headline)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .lineLimit(2)
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

            Label(
                Self.dateFormat.format(transfer.occurredAt),
                systemImage: "calendar"
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(MonMonTheme.textSecondary)
        }
    }

    private var route: String {
        "\(name(of: sourceAccount)) to \(name(of: destinationAccount))"
    }

    private var subtitle: String {
        let trimmedNote = transfer.note.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedNote.isEmpty ? AppText.string("Internal transfer", in: locale) : trimmedNote
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
